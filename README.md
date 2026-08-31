# MonetLoader 3.8.0
A Lua script loader for GTA: San Andreas (and SAMP) on Android.<br>
Main goal - compatibility with PC MoonLoader (as far as Mobile allows it).

## PC (MoonLoader) script compatibility:
* `require 'mimgui'` — native mobile ImGui binding (ImGui 1.72-style API).
* `require 'imgui'` — compatibility layer implementing the PC MoonImGui API
  (`imgui.Process`, `OnDrawFrame`/`BeforeDrawFrame`, `ImBool`/`ImFloat4`/`ImBuffer`
  buffers with `.v`, `ImColor`, `IM_COL32`, legacy enum names such as
  `Col.ChildWindowBg`/`TreeNodeFlags.AllowOverlapMode`, `GetContentRegionAvailWidth`, etc.)
  on top of `mimgui`, so PC scripts written for MoonLoader's `imgui` module can run unmodified
  next to mimgui-based scripts.
* `require 'vkeys'` — standard MoonLoader virtual-key constants (`VK_*`, `id_to_name`, `name_to_id`).
* `require 'encoding'` — MoonLoader-compatible text encoding module built on
  `monet_cp1251_to_utf8`/`monet_utf8_to_cp1251`; CP1251-encoded PC scripts
  (`u8:encode`/`u8'default'`) work unmodified.
* Keyboard-related globals from PC (`isKeyDown`, `isKeyJustPressed`, `wasKeyPressed`,
  `isKeyAvailable`, `setVirtualKeyDown`, `showCursor`) are present as no-ops/false stubs:
  there is no PC keyboard on Android, but this lets old scripts load and run. `isCharAlive`
  is implemented for real.

## Source layout:
1. `cpp` - Main MonetLoader code.
   * `game` - GTA and SAMP stuff.
   * `gui` - ImGui, input and script rendering framework.
   * `hook` - MonetHook hooking library.
   * `script` - Main script runtime implementation, `script/modules` contains packaged into MonetLoader modules.
   * `utils` - Various utility.
2. `dist` - Lua redistributable libraries.
3. `example` - Example MonetLoader scripts.
4. `lib` - Third-party code.

## Installation:
1. Setup NDK environment (toolchain, ANDROID_ABI, ANDROID_PLATFORM, ANDROID_STL).
2. Load the root CMakeLists.txt, wait for it to configure and build.
3. Ship generated libmonetloader.so together with respective Lua binary from lib/lua/bin.
4. Copy data from `dist` and scripts into `Android/media/<package name>` at external storage.