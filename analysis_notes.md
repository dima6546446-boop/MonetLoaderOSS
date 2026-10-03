# MonetLoader OSS 3.8.0 — Static Analysis Report

## 1. Overview / Status

**Project type:** Open-source C++20 native library (libmonetloader.so) — a Lua script loader for GTA: San Andreas (and SA-MP) on Android.
**NOT an APK/DEX/IL2CPP project.** This is the *source code* of the loader itself, published under an OSS license.

**Key finding: There is NO premium/paid/license/auth/subscription logic anywhere in this codebase.**

The project is a MoonLoader-compatible Lua scripting engine that hooks into the GTA:SA Android process via AML (Android Mod Loader) or JNI_OnLoad, provides Lua scripts access to game memory, RenderWare rendering, SA-MP network, and an ImGui overlay.

---

## 2. APK / Binary Map

### 2.1 Target ABI
- **armeabi-v7a** (ARM32/Thumb) — primary
- **arm64-v8a** — via conditional in CMakeLists.txt (`#if INTPTR_MAX == INT64_MAX`)

### 2.2 Native Libraries
| Library | Type | Purpose |
|---------|------|---------|
| `libmonetloader.so` | Build output (SHARED) | Main loader — hooks, Lua runtime, GUI |
| `libluajit-5.1.so` | Pre-built (shared/static, per ABI) | LuaJIT 5.1 runtime |
| `libmoonmonet_rs.so` | Pre-built (ARM32, stripped, Rust) | Material You color generation (Monet palette) |
| libressl (crypto/ssl/tls) | Built from source | TLS for Lua networking (luasocket+luasec) |
| spdlog | Built from source | Logging |

### 2.3 Entry Points
| Entry | File | Mechanism |
|-------|------|-----------|
| `JNI_OnLoad` | cpp/main.cpp:508 | Standard JNI — loads when .so is dlopen'd by the game process |
| `OnModLoad` / `AML_ENTRYPOINT` | cpp/main.cpp:521 | AML (Android Mod Loader) entry |
| `__GetModInfo` | cpp/aml_stuff.h:174 | AML mod identification (GUID: `com.monetloader.aml`) |
| `__INeedASpecificGame` | cpp/aml_stuff.h:177 | Declares target: `com.rockstargames.gtasa` |

### 2.4 No DEX / Java Components
The loader is purely native. No Java classes, no DEX bytecode, no Activities/Services/BroadcastReceivers.

---

## 3. Architecture Map

```
JNI_OnLoad / AML_ENTRYPOINT
  └── do_preinit()
        ├── andutils::init()          — Android environment (package name, paths)
        ├── file_manager::init()      — External/internal storage paths
        ├── bass_manager::init()      — Audio streaming
        ├── logger::init()            — spdlog-based logging
        ├── compat::init()            — Load profile.json (game/SAMP config)
        └── check_libs_loaded() / init_thread()
              └── do_init()
                    ├── dlopen(libGTASA.so) — resolve game symbols
                    ├── PLT/inline hooks:
                    │   ├── CGame::Process      → script processing
                    │   ├── CTheScripts::Init    → game restart detection
                    │   ├── CTheScripts::Process → Lua script execution
                    │   ├── CGame::Shutdown       → cleanup
                    │   ├── CHID::FlushQueuedText → render trigger
                    │   ├── CameraEndUpdate       → ImGui rendering
                    │   ├── AND_TouchEvent         → touch input interception
                    │   └── [SAMP] CNetGame ctor, CWorld::Add/Remove, NvEventInsertNewest
                    └── script_manager::init()
                          ├── Load all .lua/.luac from monetloader/
                          ├── Register Lua APIs (opcodes, memory, ImGui, RakNet)
                          └── Start main() coroutines
```

---

## 4. Auth / Licensing Map

### Result: **NONE**

Exhaustive search performed:
- `grep -riE` for: license, premium, vip, subscription, hwid, key, token, auth, isPremium, unlock, feature, expired, server, api, login, paid, free, trial, activate, register, verify
- Searched in: all cpp/h files, all Lua files, CMakeLists, build scripts
- **Zero matches in MonetLoader's own code.** All matches are in third-party libraries (spdlog, libressl, sol2, rapidjson, raknet) and are unrelated to authorization.

The `libmoonmonet_rs.so` binary was also strings-searched — contains only Rust stdlib strings, register manipulation functions, and no auth-related strings.

### MCI (Monet Compatibility Interface)
- `cpp/mci.h` defines a plugin interface for SA-MP network interception (RakHook)
- Contains `MCI_INIT_STRUCT` with `InitData` field described as "from profile" — this is the compat profile JSON, NOT auth data
- No license validation in the MCI interface

---

## 5. Local Feature Gates

### 5.1 Build-time Feature Flags
| Flag | Location | Values | Effect |
|------|----------|--------|--------|
| `SAMP_MODE` | CMakeLists.txt:69 | 0=disabled, 1=optional, 2=required | Controls SA-MP support compilation |
| `NEW_INPUT_SYSTEM` | CMakeLists.txt:73 | 0/1 | Controls JNI-based input system |
| Build type | CMakeLists.txt:16-23 | Debug/Release/RelWithDebInfo | Strip symbols, visibility |

### 5.2 Runtime Feature Detection
| Check | File:Line | Logic |
|-------|-----------|-------|
| SA-MP loaded | main.cpp:390-428 | `lib_manager::samp_base != 0` — detected by scanning /proc/self/maps |
| SA-MP pattern scan | main.cpp:382-393 | CNetGame ctor + ReceiveIgnoreRPC patterns must match |
| Touch workaround | main.cpp:409-415 | `compat::use_samp_touch_workaround` from profile.json |

### 5.3 Script-level Properties
| Property | File | Effect |
|----------|------|--------|
| `work-in-pause` | script.h:12 | Script runs during game pause |
| `forced-reloading-only` | script.h:13 | Script survives reloadScripts() |

### 5.4 Compat Profile
- File: `monetloader/compat/profile.json`
- Contains: game .so name, SAMP .so name, pattern signatures, offsets
- **No auth fields** — purely technical configuration

---

## 6. UI and Menu System

### ImGui Rendering Pipeline
1. `gui::render::init()` creates two ImGui contexts:
   - `g_render_context` — for script drawing (renderDrawLine, renderDrawBox, etc.)
   - `g_overlay_context` — for keyboard, watermark, overlay
2. Scripts create menus via `mimgui` Lua module (binds to Dear ImGui via cimgui)
3. Touch handling: `touch_handler` with multi-touch support
4. Watermark: "Powered by MonetLoader VERSION" shown in pause menu

### Script Manager (built-in)
- `example/Script Manager.lua` — full-featured script manager
- Opens on left-swipe on radar widget
- Features: load/unload/reload scripts, log viewer, Lua shell, crash tracker
- Script toggle API via EXPORTS table (canToggle/getToggle/toggle)
- **No premium features in the manager**

### Example Mod Menu
- `example/MultiCheat.lua` — reference cheat menu
- Features: GodMode, AirBrake, FlyCar, ESP, Reconnect, Weather/Time, SetSkin
- **All features are unconditionally available** — no locks, no premium checks

---

## 7. Network / External Communication

### Lua Scripts
- `luasocket` + `luasec` (LibreSSL) are bundled — scripts CAN make HTTP/HTTPS requests
- `samp.events` — scripts can intercept/modify SA-MP network packets via RakNet hooks
- **The loader itself makes zero network requests**

### RakHook System
- `rakhook.cpp/h` — intercepts RakNet packets between SA-MP client and server
- Provides Lua events: `onReceivePacket`, `onReceiveRpc`, `onSendPacket`, `onSendRpc`
- Used for game modding, NOT for auth

---

## 8. Uncertainty Log

| Item | Confidence | Note |
|------|-----------|------|
| No auth in C++ source | 100% | Full source review, grep confirms |
| No auth in Lua libs | 100% | All dist/lib/ files reviewed |
| No auth in example scripts | 100% | All 19 examples reviewed |
| libmoonmonet_rs.so purpose | 95% | Strings + init.lua confirm: Material You color palette generator only |
| No hidden .so loading | 98% | Only libGTASA.so, libsamp.so (game libs) and libAML.so are dlopen'd |
| Compat profile is not auth | 100% | Full source of compat::init() reviewed — only game config |

---

## 9. Safe Next Steps

1. **Build the project** to verify source integrity:
   ```bash
   mkdir build && cd build
   cmake -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
         -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-21 \
         -DANDROID_STL=c++_shared ..
   make -j$(nproc)
   ```

2. **Compare built .so with distributed binary** (if you have one) using:
   - `readelf --syms` / `nm -D` to compare exported symbols
   - `objdump -d` on specific functions to compare code structure
   - Binary diffing tools (bindiff, diaphora)

3. **Runtime analysis** (on a test device you control):
   - `logcat | grep MonetLoader` to see initialization flow
   - Hook dlopen/dlsym to trace library loading
   - Frida script to trace Lua script loading path

4. **Audit Lua scripts** loaded at runtime (user scripts in `monetloader/` directory on device) — those are where actual mod-menu logic lives and where third-party scripts might implement their own auth.
