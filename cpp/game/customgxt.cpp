#include "customgxt.h"
#include "CMessages.h"
#include "common.h"
#include "game/common.h"
#include "game/customgxt.h"
#include "hook/monethook.h"
#include "lib_manager.h"
#include <dlfcn.h>
#include <unordered_map>

namespace {
int g_gxt_key_id = 1;
std::unordered_map<std::string, std::uint16_t*> g_custom_gxt_map;

monethook::plt_hook<std::uint16_t*(void*, const char*)> o_ctext_get;
std::uint16_t* h_ctext_get(void* self, const char* tag)
{
  auto it = g_custom_gxt_map.find(tag);
  if (it == g_custom_gxt_map.end()) {
    return o_ctext_get(self, tag);
  }

  return it->second;
}

std::uint16_t* find_raw(const char* gxt_key)
{
  return h_ctext_get(reinterpret_cast<void*>(lib_manager::thetext), gxt_key);
}

std::string gxt_key_id_to_string(int value)
{
  std::string buf;
  buf.reserve(7);

  int quotient = value;
  do {
    buf += "0123456789ABCDEFGHIJKLMNOPQRSTUV"[quotient % 32];
    quotient /= 32;
  } while (quotient);

  std::reverse(buf.begin(), buf.end());
  if (buf.size() > 7) {
    buf.resize(7);
  }
  buf.insert(0, 7 - buf.size(), '0');
  return buf;
}
}

void customgxt::init(monethook::plt_scanner& sc)
{
  auto ctext_get = sc.sym("_ZN5CText3GetEPKc");
  o_ctext_get = { ctext_get, h_ctext_get };
  o_ctext_get.apply();
}

std::string customgxt::find(const char* gxt_key)
{
  std::uint16_t* raw = find_raw(gxt_key);
  if (!raw) {
    return "";
  }
  return game::GxtCharToAscii(raw);
}

void customgxt::add(std::string gxt_key, const char* ascii)
{
  auto* buf = new std::uint16_t[std::strlen(ascii) + 1];
  game::AsciiToGxtChar(ascii, buf);

  auto it = g_custom_gxt_map.find(gxt_key);
  if (it != g_custom_gxt_map.end()) {
    delete[] it->second;
    g_custom_gxt_map.erase(it);
  }
  g_custom_gxt_map.try_emplace(std::move(gxt_key), buf);
}

void customgxt::remove(std::string gxt_key)
{
  auto it = g_custom_gxt_map.find(gxt_key);
  if (it == g_custom_gxt_map.end()) {
    return;
  }

  delete[] it->second;
  g_custom_gxt_map.erase(it);
}

std::string customgxt::find_free_gxt_key()
{
  std::string result;
  while (true) {
    result = gxt_key_id_to_string(g_gxt_key_id++);
    std::uint16_t* gxt_entry = find_raw(result.c_str());
    if (!gxt_entry || gxt_entry[0] == 0) {
      return result;
    }
  }
}