#include "script_manager.h"
#include "clipboard.h"
#include "compat.h"
#include "encoding.h"
#include "file_manager.h"
#include "game/CMatrix.h"
#include "game/CMessages.h"
#include "game/CPad.h"
#include "game/CPlayerPed.h"
#include "game/CPools.h"
#include "game/CQuaternion.h"
#include "game/CRadar.h"
#include "game/CTouchInterface.h"
#include "game/MobileMenu.h"
#include "game/common.h"
#include "game/customgxt.h"
#include "game/netinfo.h"
#include "gui/render.h"
#include "lib_manager.h"
#include "logger.h"
#include "luabass.h"
#include "luafuncs.h"
#include "luajson.h"
#include "modules/cjson/lua_cjson.h"
#include "modules/effil/lua-module.h"
#include "modules/lbase64.h"
#include "modules/lfs.h"
#include "modules/luasec/api.h"
#include "modules/luasocket/luasocket.h"
#include "modules/luasocket/mime.h"
#include "modules/luasocket/serial.h"
#include "modules/luasocket/unix.h"
#include "modules/memory.h"
#include "modules/mimgui/renderer.h"
#include "opcodes.h"
#include "sol/sol.hpp"
#include "thread.h"
#include <filesystem>
#include <optional>

namespace {
class wait_task : public lua::scheduler_task {
  public:
  wait_task(int ms)
      : _end(std::chrono::steady_clock::now() + std::chrono::milliseconds(ms))
  {
  }

  bool is_complete() override
  {
    return std::chrono::steady_clock::now() >= _end;
  }

  private:
  std::chrono::time_point<std::chrono::steady_clock> _end;
};

class infinite_task : public lua::scheduler_task {
  public:
  infinite_task() = default;

  bool is_complete() override
  {
    return false;
  }
};

// not working for cross device links
// bool move_recursive(const std::filesystem::path& old_path, const std::filesystem::path& new_path)
// {
//   if (std::filesystem::exists(old_path) && std::filesystem::is_directory(old_path)) {
//     std::vector<std::filesystem::path> rename_list {};
//     for (const auto& entry : std::filesystem::recursive_directory_iterator(old_path)) {
//       if (std::filesystem::is_regular_file(entry) || std::filesystem::is_symlink(entry)) {
//         rename_list.emplace_back(entry.path());
//       }
//     }

//     for (auto& i : rename_list) {
//       std::filesystem::path new_file_path = new_path / std::filesystem::relative(i, old_path);
//       std::filesystem::create_directories(new_file_path.parent_path());
//       std::filesystem::rename(i, new_file_path);
//     }

//     std::filesystem::remove(old_path);
//     return true;
//   }

//   return false;
// }

bool move_recursive(const std::filesystem::path& old_path, const std::filesystem::path& new_path)
{
  if (std::filesystem::exists(old_path) && std::filesystem::is_directory(old_path)) {
    std::error_code ec;

    auto old_log_path = old_path / logger::relative_path;
    if (std::filesystem::exists(old_log_path)) {
      std::filesystem::remove(old_log_path, ec);
      ec.clear();
    }

    std::filesystem::copy(old_path, new_path,
        std::filesystem::copy_options::overwrite_existing | std::filesystem::copy_options::recursive, ec);
    if (ec) {
      logger::log<logger::LV_SYSTEM>(nullptr, "{}", "Failed to move files. Make sure you have enough storage.");
      ec.clear();
      return true;
    }

    std::filesystem::remove_all(old_path, ec);
    if (ec) {
      ec.clear();
      std::filesystem::path dirname = old_path.filename();

      int i = 1;
      std::filesystem::path move_to_path = old_path.parent_path() / (dirname.string() + "_old");
      while (std::filesystem::exists(move_to_path)) {
        move_to_path = old_path.parent_path() / (dirname.string() + "_old" + std::to_string(i));
        ++i;
      }

      std::filesystem::rename(old_path, move_to_path);
    }
    return true;
  }

  return false;
}
}

void lua::script_manager::init()
{
  if (_initialized) {
    return;
  }

  logger::log<logger::LV_SYSTEM>(nullptr, "{}", "\n\n\n\t* MonetLoader initialized! Version: " PROJECT_VERSION "\n\t* Official Telegram: t.me/MonetLoader\n\n");

  // migrate from legacy storage (Android/data/monetloader one)
  std::filesystem::path monetloader_path = file_manager::public_external_storage / "monetloader";
  if (move_recursive(file_manager::external_storage / "monetloader", monetloader_path)) {
    logger::log<logger::LV_SYSTEM>(nullptr, "{}", "Migrated to new storage under Android/media from Android/data.");
  }

  // setup
  _main_thread_id = gettid();
  _root_path = monetloader_path;
  std::filesystem::current_path(monetloader_path);
  init_modules();

  gui::render::new_frame();
  load_all();

  for_each_event_handler("onSystemInitialized", [](sol::protected_function fn) -> std::optional<sol::error> {
    auto pfr = fn();
    if (!pfr.valid()) {
      sol::error e = pfr;
      return e;
    }
    return std::nullopt;
  });
  run_queued_actions();

  start_main_all();
  gui::render::end_frame();

  _initialized = true;
}

void lua::script_manager::shutdown()
{
  // std::lock_guard<std::mutex> lock { _gil };

  if (!_initialized) {
    return;
  }

  for_each_event_handler("onQuitGame", [](sol::protected_function fn) -> std::optional<sol::error> {
    auto pfr = fn();
    if (!pfr.valid()) {
      sol::error e = pfr;
      return e;
    }
    return std::nullopt;
  });
  run_queued_actions();

  for (auto it = _scripts.begin(); it != _scripts.end();) {
    it = destroy_script(it, destroy_script_type::quit);
  }

  _commands.clear();
  _loaded_paths.clear();
  _scripts.clear();
  _modules.clear();
  _queued_actions.clear();
  _reload_all_later = false;
  _next_script_id = 1;
  _initialized = false;
}

std::optional<std::size_t> lua::script_manager::load(std::filesystem::path path)
{
  path = std::filesystem::weakly_canonical(path).make_preferred();
  if (_loaded_paths.find(path) != _loaded_paths.end())
    return std::nullopt;

  logger::log<logger::LV_SYSTEM>(nullptr, "{} '{}'...", "Loading script:", path.string());
  std::size_t script_id = _next_script_id++;
  _scripts.try_emplace(script_id, script_id, path);
  script& ref = _scripts.at(script_id);

  // Script stuff
  register_packages(ref.state);
  register_core_functions(ref);
  register_script_info_functions(ref);
  register_thread_functions(ref);
  register_memory_functions(ref);

  // Opcodes
  opcodes::reg(ref.state);
  register_opcode_extensions(ref);
  register_cleo_opcodes(ref);
  register_sampfuncs_opcodes(ref);

  // Variables
  register_globals(ref);
  register_handles(ref);

  auto e = start(ref, path.string());
  if (e.has_value()) {
    ref.dying = true;
    logger::log<logger::LV_ERROR>(&ref, "{}", e->what());
    logger::log<logger::LV_ERROR>(&ref, "{}", "Script died due to an error.");
    destroy_script(_scripts.find(script_id), destroy_script_type::silent);
    return std::nullopt;
  } else {
    logger::log<logger::LV_SYSTEM>(&ref, "{}", "Loaded successfully.");

    _loaded_paths.emplace(path, script_id);
    for_each_event_handler("onScriptLoad", [&ref = ref](sol::protected_function fn) -> std::optional<sol::error> {
      auto pfr = fn(ref.info);
      if (!pfr.valid()) {
        sol::error e = pfr;
        return e;
      }
      return std::nullopt;
    });

    return script_id;
  }
}

void lua::script_manager::one_off_load(std::filesystem::path path)
{
  auto o = load(path);
  if (o.has_value()) {
    auto it = _scripts.find(*o);
    if (it == _scripts.end())
      return;

    auto o_2 = start_main(it->second);
    if (o_2.has_value()) {
      it->second.dying = true;
      logger::log<logger::LV_ERROR>(&it->second, "{}", o_2->what());
      destroy_script(it, destroy_script_type::error);
    }
  }
}

void lua::script_manager::load_all()
{
  std::filesystem::path path { _root_path };
  std::filesystem::create_directories(path);
  std::filesystem::create_directories(path / "lib");
  std::filesystem::create_directories(path / "config");

  std::string ext_lua { ".lua" };
  std::string ext_luac { ".luac" };
  for (auto& i : std::filesystem::directory_iterator(path)) {
    if (i.is_regular_file() && (i.path().extension() == ext_lua || i.path().extension() == ext_luac)) {
      load(i.path());
    }
  }

  run_queued_actions();
}

void lua::script_manager::run(bool in_pause)
{
  // std::lock_guard<std::mutex> lock { _gil };
  gui::render::new_frame();

  run_queued_actions();

  if (_reload_all_later) {
    for (auto it = _scripts.begin(); it != _scripts.end();) {
      if (it->second.flags & script_flags::forced_reloading_only) {
        it->second.sched.run(in_pause);
        ++it;
      } else {
        it = destroy_script(it, destroy_script_type::normal);
      }
    }
    run_queued_actions();

    load_all();
    start_main_all();
    _reload_all_later = false;
  } else {
    for (auto it = _scripts.begin(); it != _scripts.end();) {
      auto o = it->second.sched.run(in_pause);
      if (o.has_value()) {
        it->second.dying = true;
        logger::log<logger::LV_ERROR>(&it->second, "{}", o->what());
        it = destroy_script(it, destroy_script_type::error);
      } else if (it->second.event_handlers.size() == 0 && it->second.sched.pending_tasks() == 0) {
        it = destroy_script(it, destroy_script_type::normal);
      } else {
        ++it;
      }
    }
  }

  run_queued_actions();

  gui::render::end_frame();
}

void lua::script_manager::run_queued_actions()
{
  for (auto& i : _queued_actions) {
    if (i.type == script_action::action_type::reload) {
      auto it = _scripts.find(i.id);
      if (it == _scripts.end())
        continue;
      std::string path = it->second.info.path;
      destroy_script(it, destroy_script_type::normal);
      _queued_actions.push_back(script_action { 0, path, script_action::action_type::load });
    } else if (i.type == script_action::action_type::unload) {
      auto it = _scripts.find(i.id);
      if (it == _scripts.end())
        continue;
      destroy_script(it, destroy_script_type::normal);
    } else if (i.type == script_action::action_type::load) {
      one_off_load(i.path);
    } else if (i.type == script_action::action_type::perform_real_unload) {
      // perform real unload
      auto siter = _scripts.find(i.id);
      if (siter == _scripts.end())
        continue;
      _loaded_paths.erase(siter->second.info.path);
      _scripts.erase(siter);
    }
  }
  _queued_actions.clear();
}

void lua::script_manager::on_game_restart()
{
  _reload_all_later = true; // Reinit all scripts that are not forced-reloading-only

  // Scripts were reinitialized, handles were changed
  for (auto& i : _scripts) {
    register_handles(i.second);
  }
}

std::optional<sol::error> lua::script_manager::start(script& s, const std::string& path)
{
  // Run compat scripts (preload)
  for (auto& i : compat::compat_scripts) {
    std::filesystem::path compat_script_path = _root_path / i;
    if (std::filesystem::exists(compat_script_path)) {
      auto pfr = s.state.safe_script_file(_root_path / i);
      if (!pfr.valid()) {
        sol::error e = pfr;
        return e;
      }
    }
  }

  // Run main script
  auto pfr = s.state.safe_script_file(path);
  if (!pfr.valid()) {
    sol::error e = pfr;
    return e;
  }

  static const char* GOOD_EVENTS[] {
    "onExitScript",
    "onQuitGame",
    "onScriptLoad",
    "onScriptTerminate",
    "onSystemInitialized",
    "onScriptMessage",
    "onSystemMessage",
    "onReceivePacket",
    "onReceiveRpc",
    "onSendPacket",
    "onSendRpc",
    "onTouch"
  };
  for (auto i : GOOD_EVENTS) {
    sol::protected_function pf = s.state[i];
    if (pf.valid()) {
      s.event_handlers[i].emplace_back(s.state, pf);
    }
  }

  return std::nullopt;
}

std::optional<sol::error> lua::script_manager::start_main(script& s)
{
  if (s.main_thread_id != 0)
    return std::nullopt;

  sol::protected_function f = s.state["main"];
  if (f.valid()) {
    auto v = s.sched.start(f, s.flags & script_flags::work_in_pause);
    if (std::holds_alternative<sol::error>(v)) {
      return std::get<sol::error>(v);
    } else {
      s.main_thread_id = std::get<std::size_t>(v);
    }
  }

  return std::nullopt;
}

void lua::script_manager::start_main_all()
{
  for (auto it = _scripts.begin(); it != _scripts.end();) {
    auto o = start_main(it->second);
    if (o.has_value()) {
      it->second.dying = true;
      logger::log<logger::LV_ERROR>(&it->second, "{}", o->what());
      it = destroy_script(it, destroy_script_type::error);
    } else {
      ++it;
    }
  }

  run_queued_actions();
}

lua::script_manager::script_map_type::iterator lua::script_manager::destroy_script(script_map_type::iterator siter, destroy_script_type type)
{
  if (siter == _scripts.end()) {
    return siter;
  }

  siter->second.dying = true;

  if (type != destroy_script_type::silent) {
    bool has_error = type == destroy_script_type::error;
    bool has_quit = type == destroy_script_type::quit;

    // Placed here to match moonloader behaviour
    if (has_error) {
      logger::log<logger::LV_ERROR>(&siter->second, "{}", "Script died due to an error.");
    } else {
      logger::log<logger::LV_SYSTEM>(&siter->second, "{}", "Script terminated.");
    }

    for_each_event_handler("onScriptTerminate", [siter, has_quit](sol::protected_function fn) -> std::optional<sol::error> {
      auto pfr = fn(siter->second.info, has_quit);
      if (!pfr.valid()) {
        sol::error e = pfr;
        return e;
      }

      return std::nullopt;
    });

    if (!siter->second.dead && !has_error) {
      auto it = siter->second.event_handlers.find("onExitScript");
      if (it != siter->second.event_handlers.end()) {
        for (auto i : it->second) {
          auto pfr = i(has_quit);
          if (!pfr.valid()) {
            sol::error e = pfr;
            logger::log<logger::LV_ERROR>(&siter->second, "{}", e.what());
            break;
          }
        }
      }
    }
  }

  // _loaded_paths.erase(siter->second.info.path);
  // return _scripts.erase(siter);
  siter->second.dead = true;
  _queued_actions.emplace_back(script_action { siter->second.info.id, "", script_action::action_type::perform_real_unload });
  return ++siter;
}

void lua::script_manager::init_modules()
{
  _modules.emplace("__mimgui_renderer",
      sol::c_call<decltype(&mimgui::reg_renderer), &mimgui::reg_renderer>);
  _modules.emplace("cjson", luaopen_cjson);
  _modules.emplace("cjson.safe", luaopen_cjson_safe);
  _modules.emplace("lfs", luaopen_lfs);
  _modules.emplace("base64", luaopen_base64);
  _modules.emplace("effil", luaopen_effil);

  _modules.emplace("socket.core", luaopen_socket_core);
  _modules.emplace("socket.unix", luaopen_socket_unix);
  _modules.emplace("socket.serial", luaopen_socket_serial);
  _modules.emplace("mime.core", luaopen_mime_core);

  _modules.emplace("ssl.core", luaopen_ssl_core);
  _modules.emplace("ssl.context", luaopen_ssl_context);
  _modules.emplace("ssl.x509", luaopen_ssl_x509);
  _modules.emplace("ssl.config", luaopen_ssl_config);
}

void lua::script_manager::register_packages(sol::state_view state)
{
  static std::string path = []() {
    std::string path {};
    path.reserve(_root_path.string().length() * 8 + 100); // must be enough

    std::filesystem::path lib_path = _root_path / "lib";
    path += lib_path / "?.lua";
    path += ';';
    path += lib_path / "?/init.lua";
    path += ';';
    path += _root_path / "?.lua";
    path += ';';
    path += _root_path / "?/init.lua";
    path += ';';
    path += lib_path / "?.luac";
    path += ';';
    path += lib_path / "?/init.luac";
    path += ';';
    path += _root_path / "?.luac";
    path += ';';
    path += _root_path / "?/init.luac";

    return path;
  }();
  static std::string cpath = []() {
    return (_root_path / "lib/?.so").string();
  }();

  sol::table package = state["package"];
  package["path"] = path;
  package["cpath"] = cpath;
  state.add_package_loader(+[](lua_State* L) -> int {
    const char* module_name = luaL_checkstring(L, 1);

    lua_CFunction func = nullptr;
    {
      auto it = _modules.find(module_name);
      if (it != _modules.end()) {
        func = it->second;
      }
    }

    if (func) {
      lua_pushcfunction(L, func);
    } else {
      lua_pushnil(L);
    }
    return 1;
  });
}

void lua::script_manager::register_core_functions(script& s)
{
  sol::state& state = s.state;

  // General core functions
  state["print"] = [&s = s](sol::variadic_args args) {
    sol::state_view view { args.lua_state() };
    std::string str = "";
    sol::protected_function pf = view["tostring"];
    if (!pf.valid()) {
      return;
    }

    for (auto i : args) {
      sol::protected_function_result pfr = pf(i);
      if (pfr.valid()) {
        str += pfr;
      } else {
        str += sol::type_name(i.lua_state(), i.get_type());
      }
      str += " ";
    }
    if (str.size() != 0) {
      str.resize(str.size() - 1);
    }

    logger::script_log(s, "{}", str);
  };

  // MoonLoader core functions
  state["wait"] = sol::yielding([&s = s](float ms) {
    if (s.sched.current_thread_id() == 0) {
      return;
    }
    if (ms < 0) {
      return s.sched.yield<infinite_task>();
    }

    return s.sched.yield<wait_task>(ms);
  });

  state["import"] = [&s = s](std::string str_path) {
    std::filesystem::path path = std::filesystem::weakly_canonical(str_path).make_preferred();
    std::size_t script_id;

    auto it = _loaded_paths.find(path);
    if (it != _loaded_paths.end()) {
      script_id = it->second;
    } else {
      load(path);

      auto it2 = _loaded_paths.find(path);
      if (it2 != _loaded_paths.end()) {
        script_id = it2->second;
      } else {
        return std::tuple<sol::object, std::optional<std::string>>(sol::lua_nil, "?");
      }
    }

    return std::tuple<sol::object, std::optional<std::string>>(get_script(script_id)->get_exports(s.id), std::nullopt);
  };

  state["addEventHandler"] = [&s = s](const char* name, sol::protected_function handler) {
    s.event_handlers[name].emplace_back(s.state, handler);
  };
  state["getMoonloaderVersion"] = []() {
    return 27;
  };
  state["encodeJson"] = [](sol::table table, std::optional<bool> compact) {
    return luajson::encode(table, compact.has_value() ? *compact : true);
  };
  state["decodeJson"] = [](sol::this_state state, std::string_view json) {
    return luajson::decode(state, json);
  };
  state["getGameDirectory"] = []() {
    return (file_manager::external_storage / "files").string();
  };
  state["getWorkingDirectory"] = []() {
    return _root_path.string();
  };
  state["setClipboardText"] = [](const char* text) {
    clipboard::set(text);
  };
  state["getClipboardText"] = []() {
    return clipboard::get();
  };

  // MonetLoader core functions
  state["monet_cp1251_to_utf8"] = [](std::string_view cp1251) {
    return encoding::cp1251_to_utf8(cp1251);
  };
  state["monet_utf8_to_cp1251"] = [](std::string_view utf8) {
    return encoding::utf8_to_cp1251(utf8);
  };
}

void lua::script_manager::register_script_info_functions(script& s)
{
  sol::state& state = s.state;

  state.new_usertype<script::lua_info>(
      "script",
      sol::no_constructor,
      sol::meta_function::equal_to, sol::object(state, sol::in_place, &script::lua_info::operator==),
      "this", sol::readonly_property([&s = s]() { return s.info; }),
      "name", sol::readonly(&script::lua_info::name),
      "description", sol::readonly(&script::lua_info::description),
      "version_num", sol::readonly(&script::lua_info::version_number),
      "version", sol::readonly(&script::lua_info::version),
      "authors", sol::readonly_property([](script::lua_info& self, sol::this_state state) {
        sol::table authors { state, sol::new_table { static_cast<int>(self.authors.size()) } };
        int i = 1;
        for (auto& it : self.authors) {
          authors[i] = it;
          ++i;
        }
        return authors;
      }),
      "dependencies", sol::readonly_property([](script::lua_info& self, sol::this_state state) {
        sol::table dependencies { state, sol::new_table { static_cast<int>(self.dependencies.size()) } };
        int i = 1;
        for (auto& it : self.dependencies) {
          dependencies[i] = it;
          ++i;
        }
        return dependencies;
      }),
      "path", sol::readonly(&script::lua_info::path),
      "filename", sol::readonly(&script::lua_info::filename),
      "directory", sol::readonly(&script::lua_info::directory),
      "frozen", sol::var(false),
      "dead", sol::readonly_property(&script::lua_info::get_dead),
      "id", sol::readonly(&script::lua_info::id),
      "url", sol::readonly(&script::lua_info::url),
      "properties", sol::readonly_property([](sol::this_state state, script::lua_info& self) {
        sol::table properties { state, sol::new_table { static_cast<int>(self.properties.size()) } };
        int i = 1;
        for (auto& it : self.properties) {
          properties[i] = it;
          ++i;
        }
        return properties;
      }),
      "exports", sol::readonly_property([&s = s](script::lua_info& self) -> sol::object {
        script* this_s = get_script(self.id);
        if (!this_s) {
          return sol::lua_nil;
        }

        return this_s->get_exports(s.id);
      }),
      "pause", []() {},
      "resume", []() {},
      "unload", [](script::lua_info& self) {
        if (!self.get_dead())
          _queued_actions.push_back(script_action { self.id, "", script_action::action_type::unload }); },
      "reload", [](script::lua_info& self) {
        if (!self.get_dead())
          _queued_actions.push_back(script_action { self.id, "", script_action::action_type::reload }); },
      "load", [](std::string path) { _queued_actions.push_back(script_action { 0, path, script_action::action_type::load }); },
      "find", [](std::string name) {
        for(auto& i : _scripts) {
          if (i.second.info.name == name) {
            return std::optional<script::lua_info>(i.second.info);
          }
        }
        return std::optional<script::lua_info>(std::nullopt); },
      "get", [](std::size_t id) {
        auto it = _scripts.find(id);
        if (it == _scripts.end()) {
          return std::optional<script::lua_info>(std::nullopt);
        }
        return std::optional<script::lua_info>(it->second.info); },
      "list", [](sol::this_state state) {
        sol::table scripts { state, sol::new_table { static_cast<int>(_scripts.size()) } };
        int i = 1;
        for (auto& it : _scripts) {
          scripts[i] = it.second.info;
          ++i;
        }
        return scripts; });

  state["script_name"] = [&s = s](std::string name) {
    s.info.name = name;
  };
  state["script_author"] = [&s = s](sol::variadic_args args) {
    for (auto i : args) {
      s.info.authors.push_back(i);
    }
  };
  state["script_authors"] = [&s = s](sol::variadic_args args) {
    for (auto i : args) {
      s.info.authors.push_back(i);
    }
  };
  state["script_description"] = [&s = s](std::string description) {
    s.info.description = description;
  };
  state["script_version"] = [&s = s](std::string version) {
    s.info.version = version;
  };
  state["script_version_number"] = [&s = s](int number) {
    s.info.version_number = number;
  };
  state["script_url"] = [&s = s](std::string url) {
    s.info.url = url;
  };
  state["script_dependencies"] = [&s = s](sol::variadic_args args) {
    for (auto i : args) {
      s.info.dependencies.push_back(i);
    }
  };
  state["script_moonloader"] = [](int moonloader) {};
  state["script_properties"] = [&s = s](sol::variadic_args args) {
    for (auto i : args) {
      s.apply_property(i);
    }
  };

  state["reloadScripts"] = []() {
    _reload_all_later = true;
  };
  state["thisScript"] = [&s = s]() {
    return s.info;
  };
}

void lua::script_manager::register_thread_functions(script& s)
{
  s.state.new_usertype<thread>(
      "lua_thread",
      "create", sol::factories([&s = s](sol::protected_function func, sol::variadic_args args) { return thread::create(s, func, args); }),
      "create_suspended", sol::factories([&s = s](sol::protected_function func) { return thread::create_suspended(s, func); }),
      "run", &thread::run,
      "status", &thread::status,
      "terminate", &thread::terminate,
      "work_in_pause", sol::property(&thread::get_work_in_pause, &thread::set_work_in_pause),
      "dead", sol::readonly_property(&thread::get_dead));
}

void lua::script_manager::register_memory_functions(script& s)
{
  sol::state& state = s.state;

  // Memory module is now implemented as lua, but we still use internally memory for other functions
  // s.state.require("memory", sol::c_call<decltype(&memory::reg), &memory::reg>, false);

  state["representIntAsFloat"] = [](std::int32_t i) {
    float f;
    std::memcpy(&f, &i, sizeof(f));
    return f;
  };
  state["representFloatAsInt"] = [](float f) {
    std::int32_t i;
    std::memcpy(&i, &f, sizeof(i));
    return i;
  };

  state["writeMemory"] = &memory::write;
  state["readMemory"] = &memory::read;

  state["allocateMemory"] = [&s = s](std::size_t size) {
    void* allocation = std::malloc(size);
    if (allocation != nullptr) {
      s.allocations.insert(allocation);
    }
    return reinterpret_cast<std::uintptr_t>(allocation);
  };
  state["freeMemory"] = [&s = s](std::uintptr_t memory) {
    s.allocations.erase(reinterpret_cast<void*>(memory));
    std::free(reinterpret_cast<void*>(memory));
  };

  state["getStructElement"] = [](std::uintptr_t base, std::uintptr_t offset, std::size_t size, std::optional<bool> unprotect) {
    return memory::read(base + offset, size, unprotect);
  };
  state["getStructFloatElement"] = [](std::uintptr_t base, std::uintptr_t offset, std::optional<bool> unprotect) {
    std::uint32_t i = memory::read(base + offset, sizeof(i), unprotect);
    float f;
    std::memcpy(&f, &i, sizeof(f));
    return f;
  };
  state["setStructElement"] = [](std::uintptr_t base, std::uintptr_t offset, std::size_t size,
                                             std::int32_t value, std::optional<bool> unprotect) {
    memory::write(base + offset, size, value, unprotect);
  };
  state["setStructFloatElement"] = [](std::uintptr_t base, std::uintptr_t offset, float value, std::optional<bool> unprotect) {
    std::int32_t i;
    std::memcpy(&i, &value, sizeof(i));
    memory::write(base + offset, sizeof(i), i, unprotect);
  };
}

void lua::script_manager::register_opcode_extensions(script& s)
{
  sol::state& state = s.state;

  // MoonLoader extensions
  state["getAllChars"] = [](sol::this_state state) {
    sol::table chars { state, sol::new_table { game::netinfo::find_streamed_ped_count() } };
    int idx = 1;
    auto* pool = CPools::GetPedPool();
    for (int i = 0; i < pool->m_nSize; ++i) {
      auto* obj = pool->GetAt(i);
      if (obj) {
        chars[idx] = pool->GetRef(obj);
        ++idx;
      }
    }

    return chars;
  };

  state["getAllVehicles"] = [](sol::this_state state) {
    sol::table cars { state, sol::new_table { game::netinfo::find_streamed_car_count() } };
    int idx = 1;
    auto* pool = CPools::GetVehiclePool();
    for (int i = 0; i < pool->m_nSize; ++i) {
      auto* obj = pool->GetAt(i);
      if (obj) {
        cars[idx] = pool->GetRef(obj);
        ++idx;
      }
    }

    return cars;
  };

  state["getAllObjects"] = [](sol::this_state state) {
    sol::table objs { state, sol::create };
    int idx = 1;
    auto* pool = CPools::GetObjectPool();
    for (int i = 0; i < pool->m_nSize; ++i) {
      auto* obj = pool->GetAt(i);
      if (obj) {
        objs[idx] = pool->GetRef(obj);
        ++idx;
      }
    }

    return objs;
  };

  state["setFreeGxtEntry"] = [](const char* ascii) {
    std::string gxt_key = customgxt::find_free_gxt_key();
    customgxt::add(gxt_key, ascii);
    return gxt_key;
  };
  state["getFreeGxtKey"] = [](const char* ascii) {
    return customgxt::find_free_gxt_key();
  };

  state["isGamePaused"] = []() {
    return game::IsPaused();
  };
  state["isPauseMenuActive"] = []() {
    return game::IsPaused();
  };

  state["isOpcodesAvailable"] = []() {
    return true;
  };
  state["isCleoLoaded"] = []() {
    return true;
  };
  state["isSampfuncsLoaded"] = []() {
    return lib_manager::samp_base != 0;
  };
  state["isSampLoaded"] = []() {
    return lib_manager::samp_base != 0;
  };

  state["getCharQuaternion"] = [](int self) {
    CQuaternion quat;
    quat.Set(*CPools::GetPedPool()->GetAtRef(self)->m_matrix);
    return std::tuple<float, float, float, float>(quat.x, quat.y, quat.z, quat.w);
  };
  state["setCharQuaternion"] = [](int self, float x, float y, float z, float w) {
    CQuaternion quat { x, y, z, w };
    quat.Get(CPools::GetPedPool()->GetAtRef(self)->m_matrix);
  };

  state["convertMatrixToQuaternion"] = [](float rx, float ry, float rz, float fx, float fy, float fz, float ux, float uy, float uz) {
    CMatrix mat {};
    mat.right = CVector { rx, ry, rz };
    mat.at = CVector { fx, fy, fz };
    mat.up = CVector { ux, uy, uz };

    CQuaternion quat;
    quat.Set(mat);
    return std::tuple<float, float, float, float>(quat.x, quat.y, quat.z, quat.w);
  };
  state["convertQuaternionToMatrix"] = [](float w, float x, float y, float z) {
    CQuaternion quat { x, y, z, w };
    CMatrix mat {};
    quat.Get(&mat);

    return std::tuple<float, float, float, float, float, float, float, float, float>(
        mat.right.x, mat.right.y, mat.right.z,
        mat.at.x, mat.at.y, mat.at.z,
        mat.up.x, mat.up.y, mat.up.z);
  };

  state["lockPlayerControl"] = [](bool lock) {
    CPad::GetPad(0)->DisablePlayerControls = lock;
  };
  state["isPlayerControlLocked"] = []() {
    return CPad::GetPad(0)->DisablePlayerControls != 0;
  };
  state["setGameKeyState"] = [](int key, std::int16_t value) {
    if (key == 0) { // analog left-right
      CPad::GetPad(0)->NewState.LeftStickX = value;
    }
    if (key == 1) { // analog up-down
      CPad::GetPad(0)->NewState.LeftStickY = value;
    }
  };

  // PC MoonLoader compatibility: виртуальные клавиши (vkeys.lua). На Android
  // физической клавиатуры нет, поэтому состояние всегда «не нажата» — PC-скрипты
  // с таким подходом загружаются и не падают на проверках клавиш.
  state["isKeyDown"] = [](int) { return false; };
  state["isKeyJustPressed"] = [](int) { return false; };
  state["wasKeyPressed"] = [](int) { return false; };
  state["isKeyAvailable"] = [](int) { return false; };
  state["setVirtualKeyDown"] = [](int, bool) {};

  // PC MoonLoader compatibility: у игрока нет курсора ОС (сенсорный ввод),
  // mimgui рисует собственный курсор; вызов безвреден, чтобы PC-скрипты не падали.
  state["showCursor"] = [](bool, std::optional<bool>) {};

  state["isCharAlive"] = [](int self) {
    return CPools::GetPedPool()->GetAtRef(self) != nullptr;
  };

  // Mission Bot helpers: доступ к радар-блипам (маркеры миссий/цели)
  state["getRadarBlips"] = [](sol::this_state state) {
    sol::table blips { state, sol::create };
    int idx = 1;
    auto* traces = CRadar::GetRadarTraces();
    for (int i = 0; i < 250; ++i) {
      const auto& t = traces[i];
      if (!t.m_bInUse) {
        continue;
      }
      sol::table b { state, sol::create };
      b["slot"] = i;
      b["type"] = static_cast<int>(t.m_nBlipType); // 0 none, 1 car, 2 coord, 3 char, 4 object
      b["entity"] = static_cast<int>(t.m_nEntityHandle);
      b["x"] = t.m_vecPos.x;
      b["y"] = t.m_vecPos.y;
      b["z"] = t.m_vecPos.z;
      b["colour"] = static_cast<int>(t.m_nColour);
      b["sprite"] = static_cast<int>(t.m_nRadarSprite);
      b["short_range"] = t.m_bShortRange != 0;
      blips[idx] = b;
      ++idx;
    }
    return blips;
  };

  // Mission Bot helpers: виртуальный геймпад — запись состояния кнопок CPad(0).
  // Значение 0 = отпущено, 255 = нажато (стики: -128..128).
  // Скрипт должен выставлять состояние каждый кадр (wait 0), т.к. игра
  // перезаписывает NewState вводом с тача.
  state["setPadButtonState"] = [](const char* name, int value) {
    CControllerState& s = CPad::GetPad(0)->NewState;
    const std::int16_t v = static_cast<std::int16_t>(value < -128 ? -128 : (value > 255 ? 255 : value));
    std::string_view n { name };
    if (n == "leftx") s.LeftStickX = v;
    else if (n == "lefty") s.LeftStickY = v;
    else if (n == "rightx") s.RightStickX = v;
    else if (n == "righty") s.RightStickY = v;
    else if (n == "l1") s.LeftShoulder1 = v;
    else if (n == "l2") s.LeftShoulder2 = v;
    else if (n == "r1") s.RightShoulder1 = v;
    else if (n == "r2") s.RightShoulder2 = v;
    else if (n == "dpadup") s.DPadUp = v;
    else if (n == "dpaddown") s.DPadDown = v;
    else if (n == "dpadleft") s.DPadLeft = v;
    else if (n == "dpadright") s.DPadRight = v;
    else if (n == "start") s.Start = v;
    else if (n == "select") s.Select = v;
    else if (n == "square") s.ButtonSquare = v;
    else if (n == "triangle") s.ButtonTriangle = v;
    else if (n == "cross") s.ButtonCross = v;
    else if (n == "circle") s.ButtonCircle = v;
    else if (n == "l3") s.ShockButtonL = v;
    else if (n == "r3") s.ShockButtonR = v;
  };

  // MonetLoader extensions
  state["isWidgetPressedEx"] = [](int widget_id, int frames) {
    CVector2D out {};
    bool result = CTouchInterface::IsTouched(widget_id, &out, frames);
    if (!result) {
      return std::tuple<bool, std::optional<float>, std::optional<float>>(result, std::nullopt, std::nullopt);
    } else {
      return std::tuple<bool, std::optional<float>, std::optional<float>>(result, out.x, out.y);
    }
  };
}

void lua::script_manager::register_cleo_opcodes(script& s)
{
  sol::state& state = s.state;

  state["getCharPointer"] = [](int self) {
    return reinterpret_cast<std::uintptr_t>(CPools::GetPedPool()->GetAtRef(self));
  };
  state["getCarPointer"] = [](int self) {
    return reinterpret_cast<std::uintptr_t>(CPools::GetVehiclePool()->GetAtRef(self));
  };
  state["getObjectPointer"] = [](int self) {
    return reinterpret_cast<std::uintptr_t>(CPools::GetObjectPool()->GetAtRef(self));
  };

  state["storeClosestEntities"] = [](int self) {
    CVehicle* vehicle = nullptr;
    CPed* ped = nullptr;
    CPed* our_ped = CPools::GetPedPool()->GetAtRef(self);
    if (our_ped) {
      CPedIntelligence* intel = our_ped->m_pIntelligence;
      if (intel) {
        for (auto* entity : intel->m_vehicleScanner.m_apEntities) {
          vehicle = reinterpret_cast<CVehicle*>(entity);
          if (vehicle && !vehicle->m_nVehicleFlags.bFadeOut) {
            break;
          }
          vehicle = nullptr;
        }

        for (auto* entity : intel->m_pedScanner.m_apEntities) {
          ped = reinterpret_cast<CPed*>(entity);
          if (ped && ped != our_ped && !ped->m_nPedFlags.bFadeOut) {
            break;
          }
          ped = nullptr;
        }
      }
    }

    return std::tuple<std::optional<int>, std::optional<int>>(
        vehicle ? std::make_optional(CPools::GetVehiclePool()->GetRef(vehicle)) : std::nullopt,
        ped ? std::make_optional(CPools::GetPedPool()->GetRef(ped)) : std::nullopt);
  };

  state["getTargetBlipCoordinates"] = []() {
    std::int32_t ref = MobileMenu::Get()->waypoint_blip;
    tRadarTrace* trace = &CRadar::GetRadarTraces()[ref & 0xFFFF];
    if (ref == 0 || !trace->m_nBlipDisplay) {
      return std::tuple<bool,
          std::optional<float>,
          std::optional<float>,
          std::optional<float>>(
          false,
          std::nullopt,
          std::nullopt,
          std::nullopt);
    }

    return std::tuple<bool,
        std::optional<float>,
        std::optional<float>,
        std::optional<float>>(
        true,
        trace->m_vecPos.x,
        trace->m_vecPos.y,
        opcodes::getGroundZFor3dCoord(trace->m_vecPos.x, trace->m_vecPos.y, 9999.f));
  };

  state["getCarNumberOfGears"] = [](int self) {
    return CPools::GetVehiclePool()->GetAtRef(self)->m_pHandlingData->m_transmissionData.m_nNumberOfGears;
  };
  state["getCarCurrentGear"] = [](int self) {
    return CPools::GetVehiclePool()->GetAtRef(self)->m_nCurrentGear;
  };
  state["isCarSirenOn"] = [](int self) {
    return static_cast<bool>(CPools::GetVehiclePool()->GetAtRef(self)->m_nVehicleFlags.bSirenOrAlarm);
  };
  state["isCarEngineOn"] = [](int self) {
    return static_cast<bool>(CPools::GetVehiclePool()->GetAtRef(self)->m_nVehicleFlags.bEngineOn);
  };
  state["switchCarEngine"] = [](int self, bool state) {
    CPools::GetVehiclePool()->GetAtRef(self)->m_nVehicleFlags.bEngineOn = state;
  };

  state["printStyledString"] = [](const char* text, std::uint32_t time, std::uint16_t style) {
    if (std::strlen(text) > 256) {
      return;
    }
    game::AsciiToGxtChar(text, CMessages::GetBuffer());
    CMessages::AddBigMessage(CMessages::GetBuffer(), time, style);
  };
  state["printString"] = [](const char* text, std::uint32_t time) {
    if (std::strlen(text) > 256) {
      return;
    }
    game::AsciiToGxtChar(text, CMessages::GetBuffer());
    CMessages::AddMessage(nullptr, CMessages::GetBuffer(), time, 0, false);
  };
  state["printStringNow"] = [](const char* text, std::uint32_t time) {
    if (std::strlen(text) > 256) {
      return;
    }
    game::AsciiToGxtChar(text, CMessages::GetBuffer());
    CMessages::AddMessageJumpQ(nullptr, CMessages::GetBuffer(), time, 0, false);
  };

  state["getCharPlayerIsTargeting"] = [](int self) {
    int char_ref = opcodes::getPlayerChar(self);
    auto* player_ped = static_cast<CPlayerPed*>(CPools::GetPedPool()->GetAtRef(char_ref));
    CEntity* target = nullptr;
    if (player_ped) {
      target = player_ped->m_pTargetedObject;
      if (!target) {
        target = player_ped->m_pPlayerTargettedPed;
      }
    }

    if (target && target->m_nType == ENTITY_TYPE_PED) {
      return std::tuple<bool, std::optional<int>>(
          true,
          CPools::GetPedPool()->GetRef(static_cast<CPed*>(target)));
    } else {
      return std::tuple<bool, std::optional<int>>(
          false,
          std::nullopt);
    }
  };

  state["findAllRandomCharsInSphere"] = [&s = s](float x, float y, float z, float radius, bool find_next, bool skip_dead) {
    CVector center { x, y, z };
    auto* pool = CPools::GetPedPool();
    int last_found = s.last_ped;
    if (!find_next) {
      last_found = 0;
    }

    for (int i = last_found; i < pool->m_nSize; ++i) {
      CPed* ped = pool->GetAt(i);
      if (ped) {
        if (skip_dead && (ped->m_nPedFlags.bFadeOut || ped->m_nPedState == PEDSTATE_DEAD || ped->m_nPedState == PEDSTATE_DIE)) {
          continue;
        }

        if (radius >= 1000.f || center.DistanceSquared(ped->GetPosition()) <= radius * radius) {
          s.last_ped = i + 1;
          return std::tuple<bool, std::optional<int>>(
              true,
              pool->GetRef(ped));
        }
      }
    }

    return std::tuple<bool, std::optional<int>>(
        false,
        std::nullopt);
  };

  state["findAllRandomVehiclesInSphere"] = [&s = s](float x, float y, float z, float radius, bool find_next, bool skip_wrecked) {
    CVector center { x, y, z };
    auto* pool = CPools::GetVehiclePool();
    int last_found = s.last_vehicle;
    if (!find_next) {
      last_found = 0;
    }

    for (int i = last_found; i < pool->m_nSize; ++i) {
      CVehicle* vehicle = pool->GetAt(i);
      if (vehicle) {
        if (skip_wrecked && (vehicle->m_nVehicleFlags.bFadeOut || vehicle->m_nVehicleFlags.bIsDrowning || vehicle->m_nStatus == STATUS_WRECKED)) {
          continue;
        }

        if (radius >= 1000.f || center.DistanceSquared(vehicle->GetPosition()) <= radius * radius) {
          s.last_vehicle = i + 1;
          return std::tuple<bool, std::optional<int>>(
              true,
              pool->GetRef(vehicle));
        }
      }
    }

    return std::tuple<bool, std::optional<int>>(
        false,
        std::nullopt);
  };

  state["findAllRandomObjectsInSphere"] = [&s = s](float x, float y, float z, float radius, bool find_next) {
    CVector center { x, y, z };
    auto* pool = CPools::GetObjectPool();
    int last_found = s.last_object;
    if (!find_next) {
      last_found = 0;
    }

    for (int i = last_found; i < pool->m_nSize; ++i) {
      CObject* object = pool->GetAt(i);
      if (object && (radius >= 1000.f || center.DistanceSquared(object->GetPosition()) <= radius * radius)) {
        s.last_object = i + 1;
        return std::tuple<bool, std::optional<int>>(
            true,
            pool->GetRef(object));
      }
    }

    return std::tuple<bool, std::optional<int>>(
        false,
        std::nullopt);
  };

  state["doesFileExist"] = [](const char* path) {
    return std::filesystem::exists(path);
  };
  state["doesDirectoryExist"] = [](const char* path) {
    return std::filesystem::is_directory(path);
  };
  state["createDirectory"] = [](const char* path) {
    return std::filesystem::create_directories(path);
  };

  state["getCharPointerHandle"] = [](std::uintptr_t ptr) {
    return CPools::GetPedPool()->GetRef(reinterpret_cast<CPed*>(ptr));
  };
  state["getVehiclePointerHandle"] = [](std::uintptr_t ptr) {
    return CPools::GetVehiclePool()->GetRef(reinterpret_cast<CVehicle*>(ptr));
  };
  state["getObjectPointerHandle"] = [](std::uintptr_t ptr) {
    return CPools::GetObjectPool()->GetRef(reinterpret_cast<CObject*>(ptr));
  };

  state["getGxtText"] = [](const char* gxt_key) {
    return customgxt::find(gxt_key);
  };
  state["setGxtEntry"] = [](std::string gxt_key, const char* ascii) {
    customgxt::add(std::move(gxt_key), ascii);
  };
  state["clearGxtEntry"] = [](std::string gxt_key) {
    customgxt::remove(std::move(gxt_key));
  };

  luabass::reg(state);
}

void lua::script_manager::register_sampfuncs_opcodes(script& s)
{
  sol::state& state = s.state;

  // Command system
  state["sampRegisterChatCommand"] = [&s = s](std::string command, sol::protected_function callback) {
    return register_command(s, command, callback);
  };
  state["sampUnregisterChatCommand"] = [](std::string command) {
    return unregister_command(command);
  };
  state["sampIsChatCommandDefined"] = [](std::string command) {
    return _commands.find(command) != _commands.end();
  };
  state["sampSetClientCommandDescription"] = [](std::string_view command, std::string_view descrption) {};

  luafuncs::reg(state);
}

void lua::script_manager::register_globals(script& s)
{
  sol::state& state = s.state;

  state["MONET_VERSION"] = PROJECT_VERSION_INDEX;
  state["MONET_COMPAT_PROFILE"] = compat::profile_name;
  state["MONET_DPI_SCALE"] = gui::render::get_dpi_scale();
  state["MONET_GTASA_BASE"] = lib_manager::gtasa_base;
  state["MONET_SAMP_BASE"] = lib_manager::samp_base;
  state["null"] = sol::light<luajson::null_t> { static_cast<luajson::null_t*>(nullptr) }; // 0.27
}

void lua::script_manager::register_handles(script& s)
{
  sol::state& state = s.state;

  state["playerHandle"] = 0; // always 0 in GTA: SA
  state["PLAYER_HANDLE"] = 0;
  int playerChar = opcodes::getPlayerChar(0);
  state["playerPed"] = playerChar;
  state["PLAYER_PED"] = playerChar;
}