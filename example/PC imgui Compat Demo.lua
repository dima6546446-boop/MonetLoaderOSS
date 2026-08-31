-- MonetLoader 3.8.0
-- Reference script: PC (MoonLoader) imgui compatibility demo
--
-- Скрипт написан в стиле PC-скриптов для MoonLoader (модуль MoonImGui):
-- старый API (`require 'imgui'`, буферы с `.v`, imgui.Process, OnDrawFrame,
-- ImColor, старые имена enum'ов) эмулируется слоем dist/lib/imgui поверх
-- mimgui, а `require 'vkeys'` и `require 'encoding'` предоставляются
-- библиотеками из dist/lib.
--
-- Отличие от PC: на Android нет физической клавиатуры, поэтому меню
-- открывается командой чата /pcmenu (isKeyJustPressed всегда false).

script_name('PC imgui Compat Demo')
script_version('1.0')
script_version_number(1)
script_author('The MonetLoader Team')
script_description('Demonstrates the legacy MoonImGui (PC) API compatibility layer.')

local imgui = require 'imgui'
local vkeys = require 'vkeys'
local bit = require 'bit'
local encoding = require 'encoding'

-- этот файл хранится в UTF-8; в CP1251-скриптах с PC оставляйте 'CP1251'
encoding.default = 'UTF8'
local u8 = encoding.UTF8

local window = imgui.ImBool(false)
local text_buffer = imgui.ImBuffer(256)
local slider_value = imgui.ImFloat(50)
local color = imgui.ImFloat4(imgui.ImColor(0, 255, 166):GetFloat4())
local combo_index = imgui.ImInt(0)
local combo_items = { u8'Первый', u8'Второй', u8'Третий' }

local window_flags = 0
  + imgui.WindowFlags.NoResize
  + imgui.WindowFlags.NoCollapse
  + imgui.WindowFlags.ShowBorders -- флаг удалён в новых ImGui: совместимость = 0

function main()
  if not isSampfuncsLoaded() or not isSampLoaded() then
    return
  end
  while not isSampAvailable() do
    wait(100)
  end

  sampRegisterChatCommand('pcmenu', function()
    window.v = not window.v
    imgui.Process = window.v
  end)

  -- На PC меню обычно открывается так (на Android всегда false):
  --   if isKeyJustPressed(vkeys.VK_F5) then ... end
  printStringNow('F5 = 0x' .. bit.tobit(vkeys.VK_F5), 1500)

  wait(-1)
end

imgui.OnDrawFrame = function(player)
  if not imgui.Begin(u8'PC Compat Demo', window, window_flags) then
    imgui.End()
    return
  end

  imgui.Text(u8'Старый API MoonImGui поверх mimgui')
  imgui.TextWrapped(u8'Буферы ImBool/ImFloat/ImFloat4/ImBuffer/ImInt, ImColor, старые имена enum-ов.')

  if imgui.CollapsingHeader(u8'Элементы') then
    imgui.Checkbox(u8'Чекбокс (тот же буфер, что и окно)', window)

    imgui.PushItemWidth(-1)
    imgui.SliderFloat(u8'Слайдер', slider_value, 0, 100, u8'%.0f')
    imgui.PopItemWidth()

    if imgui.InputText(u8'Поле ввода', text_buffer, imgui.InputTextFlags.EnterReturnsTrue) then
      sampAddChatMessage(u8'Введено: ' .. text_buffer.v, imgui.ImColor(0, 255, 166):GetU32())
    end

    if imgui.Combo(u8'Список', combo_index, table.concat(combo_items, '\0') .. '\0') then
      sampAddChatMessage(u8'Выбран: ' .. combo_items[combo_index.v + 1], -1)
    end

    if imgui.ColorEdit4(u8'Цвет', color) then
      local c = imgui.ImColor.FromFloat4(color.v[1], color.v[2], color.v[3], color.v[4])
      local r, g, b = c:GetRGBA()
      printStringNow(('R:%d G:%d B:%d'):format(r, g, b), 1500)
    end

    if imgui.Button(u8'Кнопка', imgui.ImVec2(0, 40)) then
      sampAddChatMessage('GetContentRegionAvailWidth = ' .. imgui.GetContentRegionAvailWidth(), -1)
    end
  end

  imgui.Separator()
  imgui.TextDisabled(('VK_F5 = 0x%02X (vkeys.lua), EnterReturnsTrue = %d'):format(
    vkeys.VK_F5, imgui.InputTextFlags.EnterReturnsTrue))

  imgui.End()
end

function onScriptTerminate(scr)
  if scr == script.this then
    imgui.Process = false
  end
end
