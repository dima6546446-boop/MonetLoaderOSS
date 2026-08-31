--[[
    imgui — эмуляция API MoonImGui (PC MoonLoader) поверх mimgui.

    Позволяет запускать PC-скрипты, написанные под `require 'imgui'`
    (MoonImGui by FYP, blast.hk/threads/19292), без изменения кода:

      * imgui.Process / RenderInMenu / LockPlayer / ShowCursor / DisableInput
      * колбэки imgui.OnDrawFrame / imgui.BeforeDrawFrame
      * буферы ImBool / ImInt / ImFloat / ImFloat2 / ImFloat3 / ImFloat4 /
        ImBuffer с полем `.v` (как в MoonImGui)
      * класс imgui.ImColor (значения 0..255), IM_COL32, WHITE / BLACK / BLACK_TRANS
      * старые имена перечислений: Col.ChildWindowBg, Col.ComboBg,
        TreeNodeFlags.AllowOverlapMode, StyleVar.ChildWindowRounding, ...
      * GetContentRegionAvailWidth, CreateTextureFromMemory, RebuildFonts,
        ImFontAtlasGlyphRangesBuilder, SwitchContext, InputDeviceType

    Отличия от PC-версии, обусловленные платформой Android:
      * клавиатура отсутствует: IsKeyPressed/GetIO().KeysDown всегда «не нажата»;
      * imgui.GetTextureFromAddress() возвращает nil (нет RW-текстур);
      * ввод обрабатывает сенсорный рендерер mimgui (тач вместо мыши).

    Скрипты под новый API по-прежнему подключают `require 'mimgui'` —
    оба модуля работают независимо друг от друга.
]]

local mm  = require 'mimgui'
local ffi = require 'ffi'
local bit = require 'bit'

assert(MONET_VERSION, "module 'imgui' requires MonetLoader")

local imgui = {}

--------------------------------------------------------------------------------
-- Буферы старого API: структуры с полем `.v`
--------------------------------------------------------------------------------

ffi.cdef [[
typedef struct { bool  data[1]; } MLimguiBool;
typedef struct { int   data[1]; } MLimguiInt;
typedef struct { float data[1]; } MLimguiFloat;
typedef struct { float data[2]; } MLimguiFloat2;
typedef struct { float data[3]; } MLimguiFloat3;
typedef struct { float data[4]; } MLimguiFloat4;
typedef struct { char *data; int size; } MLimguiBuffer;
]]

local function field_error(typ, key)
  error(("%s: поле '%s' не найдено"):format(typ, tostring(key)), 3)
end

local function scalar_type(ctype, name)
  return ffi.metatype(ctype, {
    __new = function(ct, value)
      local self = ffi.new(ct)
      self.data[0] = value
      return self
    end,
    __index = function(self, key)
      if key == 'v' then return self.data[0] end
      field_error(name, key)
    end,
    __newindex = function(self, key, value)
      if key == 'v' then self.data[0] = value; return end
      field_error(name, key)
    end,
  })
end

local function vector_type(ctype, name, n)
  return ffi.metatype(ctype, {
    __new = function(ct, ...)
      local self = ffi.new(ct)
      local vals = { ... }
      for i = 1, n do
        self.data[i - 1] = tonumber(vals[i]) or 0.0
      end
      return self
    end,
    __index = function(self, key)
      if key == 'v' then
        -- прокси с 1-базной индексацией, как у MoonImGui (buf.v[1] == x)
        return setmetatable({}, {
          __index = function(_, i)
            if type(i) == 'number' and i >= 1 and i <= n then
              return self.data[i - 1]
            end
            error(("%s.v: индекс вне диапазона (1..%d)"):format(name, n), 2)
          end,
          __newindex = function(_, i, value)
            if type(i) == 'number' and i >= 1 and i <= n then
              self.data[i - 1] = value
              return
            end
            error(("%s.v: индекс вне диапазона (1..%d)"):format(name, n), 2)
          end,
          __len = function() return n end,
        })
      end
      field_error(name, key)
    end,
    __newindex = function(self, key, value)
      if key == 'v' then
        if ffi.istype(mm.ImVec4, value) then
          for i = 1, n do
            self.data[i - 1] = ({ value.x, value.y, value.z, value.w })[i] or 0.0
          end
        elseif type(value) == 'table' then
          for i = 1, n do
            self.data[i - 1] = tonumber(value[i]) or 0.0
          end
        else
          error(("%s.v = ожидается таблица или ImVec4"):format(name), 2)
        end
        return
      end
      field_error(name, key)
    end,
  })
end

local ImBoolT   = scalar_type('MLimguiBool',   'ImBool')
local ImIntT    = scalar_type('MLimguiInt',    'ImInt')
local ImFloatT  = scalar_type('MLimguiFloat',  'ImFloat')
local ImFloat2T = vector_type('MLimguiFloat2', 'ImFloat2', 2)
local ImFloat3T = vector_type('MLimguiFloat3', 'ImFloat3', 3)
local ImFloat4T = vector_type('MLimguiFloat4', 'ImFloat4', 4)

function imgui.ImBool(value)   return ImBoolT(value and true or false) end
function imgui.ImInt(value)    return ImIntT(math.floor(tonumber(value) or 0)) end
function imgui.ImFloat(value)  return ImFloatT(tonumber(value) or 0.0) end
function imgui.ImFloat2(x, y)  return ImFloat2T(tonumber(x) or 0.0, tonumber(y) or 0.0) end
function imgui.ImFloat3(x, y, z)
  return ImFloat3T(tonumber(x) or 0.0, tonumber(y) or 0.0, tonumber(z) or 0.0)
end
function imgui.ImFloat4(x, y, z, w)
  return ImFloat4T(tonumber(x) or 0.0, tonumber(y) or 0.0, tonumber(z) or 0.0, tonumber(w) or 0.0)
end

local ImBufferT = ffi.metatype('MLimguiBuffer', {
  __index = function(self, key)
    if key == 'v' then return ffi.string(self.data) end
    field_error('ImBuffer', key)
  end,
  __newindex = function(self, key, value)
    if key == 'v' then
      value = tostring(value)
      if #value >= self.size then value = value:sub(1, self.size - 1) end
      ffi.copy(self.data, value)
      self.data[#value] = 0
      return
    end
    field_error('ImBuffer', key)
  end,
})

function imgui.ImBuffer(size)
  size = math.floor(tonumber(size) or 0)
  assert(size > 1, 'imgui.ImBuffer(size): размер должен быть больше 1')
  local data = ffi.new('char[?]', size)
  data[0] = 0
  local buf = ImBufferT(data, size)
  -- удерживаем массив, пока жива структура (cdata-указатели GC не отслеживает)
  ffi.gc(buf, function() return data end)
  return buf
end

--------------------------------------------------------------------------------
-- Автоматическая распаковка буферов в функциях, принимающих указатели
--------------------------------------------------------------------------------

local buffer_ctypes = {
  ffi.typeof('MLimguiBool'),
  ffi.typeof('MLimguiInt'),
  ffi.typeof('MLimguiFloat'),
  ffi.typeof('MLimguiFloat2'),
  ffi.typeof('MLimguiFloat3'),
  ffi.typeof('MLimguiFloat4'),
  ffi.typeof('MLimguiBuffer'),
}

local function buffer_data(value)
  if type(value) ~= 'cdata' then return nil end
  for i = 1, #buffer_ctypes do
    if ffi.istype(buffer_ctypes[i], value) then return value.data end
  end
  return nil
end

local function pass_buffers(name, positions)
  local orig = mm[name]
  if type(orig) ~= 'function' then return end
  imgui[name] = function(...)
    local n = select('#', ...)
    local args = { ... }
    local keep = {} -- ссылки на структуры-буферы на время вызова (interior pointer)
    for _, pos in ipairs(positions) do
      local arg = args[pos]
      if arg ~= nil then
        local data = buffer_data(arg)
        if data ~= nil then
          args[pos] = data
          keep[#keep + 1] = arg
        end
      end
    end
    local a, b, c = orig(unpack(args, 1, n))
    keep = nil
    return a, b, c
  end
end

pass_buffers('Begin',           { 2 })
pass_buffers('Checkbox',        { 2 })
pass_buffers('CheckboxFlags',   { 2 })
pass_buffers('SliderFloat',     { 2 })
pass_buffers('SliderFloat2',    { 2 })
pass_buffers('SliderFloat3',    { 2 })
pass_buffers('SliderFloat4',    { 2 })
pass_buffers('SliderAngle',     { 2 })
pass_buffers('SliderInt',       { 2 })
pass_buffers('SliderInt2',      { 2 })
pass_buffers('SliderInt3',      { 2 })
pass_buffers('SliderInt4',      { 2 })
pass_buffers('VSliderFloat',    { 3 })
pass_buffers('VSliderInt',      { 3 })
pass_buffers('DragFloat',       { 2 })
pass_buffers('DragFloat2',      { 2 })
pass_buffers('DragFloat3',      { 2 })
pass_buffers('DragFloat4',      { 2 })
pass_buffers('DragFloatRange2', { 2, 3 })
pass_buffers('DragInt',         { 2 })
pass_buffers('DragInt2',        { 2 })
pass_buffers('DragInt3',        { 2 })
pass_buffers('DragInt4',        { 2 })
pass_buffers('DragIntRange2',   { 2, 3 })
pass_buffers('InputInt',        { 2 })
pass_buffers('InputInt2',       { 2 })
pass_buffers('InputInt3',       { 2 })
pass_buffers('InputInt4',       { 2 })
pass_buffers('InputFloat',      { 2 })
pass_buffers('InputFloat2',     { 2 })
pass_buffers('InputFloat3',     { 2 })
pass_buffers('InputFloat4',     { 2 })
pass_buffers('InputDouble',     { 2 })
pass_buffers('ColorEdit3',      { 2 })
pass_buffers('ColorEdit4',      { 2 })
pass_buffers('ColorPicker3',    { 2 })
pass_buffers('ColorPicker4',    { 2 })
pass_buffers('Combo',           { 2 })
pass_buffers('ListBox',         { 2 })

-- InputText: старый API не передаёт buf_size — берём его из буфера
local origInputText = mm.InputText
if type(origInputText) == 'function' then
  function imgui.InputText(label, buf, flags, ...)
    local data = buffer_data(buf)
    if data == nil then
      return origInputText(label, buf, flags, ...)
    end
    return origInputText(label, data, buf.size, tonumber(flags) or 0, ...)
  end
end

local origInputTextWithHint = mm.InputTextWithHint
if type(origInputTextWithHint) == 'function' then
  function imgui.InputTextWithHint(label, hint, buf, flags, ...)
    local data = buffer_data(buf)
    if data == nil then
      return origInputTextWithHint(label, hint, buf, flags, ...)
    end
    return origInputTextWithHint(label, hint, data, buf.size, tonumber(flags) or 0, ...)
  end
end

local origInputTextMultiline = mm.InputTextMultiline
if type(origInputTextMultiline) == 'function' then
  -- старый вызов: (label, buffer[, flags]); новый: (label, buf, size, ImVec2, flags)
  function imgui.InputTextMultiline(label, buf, size, flags, ...)
    local data = buffer_data(buf)
    if data == nil then
      return origInputTextMultiline(label, buf, size, flags, ...)
    end
    if size == nil or type(size) == 'number' then
      return origInputTextMultiline(label, data, buf.size, mm.ImVec2(0, 0), size or 0, ...)
    end
    return origInputTextMultiline(label, data, buf.size, size, tonumber(flags) or 0, ...)
  end
end

--------------------------------------------------------------------------------
-- Цвета: IM_COL32, ImColor
--------------------------------------------------------------------------------

function imgui.IM_COL32(r, g, b, a)
  return bit.bor(
    bit.lshift(bit.band(r, 0xFF), 0),
    bit.lshift(bit.band(g, 0xFF), 8),
    bit.lshift(bit.band(b, 0xFF), 16),
    bit.lshift(bit.band(a, 0xFF), 24))
end

imgui.WHITE       = imgui.IM_COL32(255, 255, 255, 255)
imgui.BLACK       = imgui.IM_COL32(0, 0, 0, 255)
imgui.BLACK_TRANS = imgui.IM_COL32(0, 0, 0, 0)

local ImVec4 = mm.ImVec4

local ImColor = {}
imgui.ImColor = ImColor

local ImColorMethods = {}

-- ВАЖНО: локальная переменная входит в область видимости только ПОСЛЕ
-- своего объявления, поэтому ImColorMT объявляется до инициализации —
-- иначе ссылки на него внутри метаметодов уйдут в глобал.
local ImColorMT
ImColorMT = {
  __index = function(self, key)
    local method = ImColorMethods[key]
    if method ~= nil then return method end
    if key == 'v' or key == 'vec4' then return self.Value end
    field_error('ImColor', key)
  end,
  __newindex = function(self, key, value)
    if key == 'Value' or key == 'v' or key == 'vec4' then
      rawset(self, 'Value', value)
      return
    end
    rawset(self, key, value) -- статики класса / поля экземпляра
  end,
  __tostring = function(self)
    local v = self.Value
    return ('ImColor(%d, %d, %d, %d)'):format(
      math.floor(v.x * 255 + 0.5), math.floor(v.y * 255 + 0.5),
      math.floor(v.z * 255 + 0.5), math.floor(v.w * 255 + 0.5))
  end,
  __call = function(_, r, g, b, a)
    -- числа задаются в шкале 0..255 (как в MoonImGui)
    if type(r) == 'cdata' then
      if ffi.istype(ImVec4, r) then
        return setmetatable({ Value = ImVec4(r.x, r.y, r.z, r.w) }, ImColorMT)
      end
      error('ImColor: неожидаемый тип аргумента', 2)
    end
    if r == nil then
      r, g, b, a = 255, 255, 255, 255
    elseif g == nil and b == nil then
      -- ImColor(ImU32)
      local u32 = bit.tobit(r)
      return setmetatable({ Value = mm.ColorConvertU32ToFloat4(u32) }, ImColorMT)
    end
    local function channel(v) return (tonumber(v) or 0) / 255 end
    return setmetatable({ Value = ImVec4(channel(r), channel(g or 255), channel(b or 255), channel(a or 255)) }, ImColorMT)
  end,
}
setmetatable(ImColor, ImColorMT)

function ImColorMethods:GetU32()
  return mm.ColorConvertFloat4ToU32(self.Value)
end
ImColorMethods.ToU32 = ImColorMethods.GetU32

function ImColorMethods:GetFloat4()
  return self.Value.x, self.Value.y, self.Value.z, self.Value.w
end

function ImColorMethods:GetVec4()
  return ImVec4(self.Value.x, self.Value.y, self.Value.z, self.Value.w)
end

function ImColorMethods:GetRGBA()
  local v = self.Value
  return math.floor(v.x * 255 + 0.5), math.floor(v.y * 255 + 0.5),
         math.floor(v.z * 255 + 0.5), math.floor(v.w * 255 + 0.5)
end

function ImColorMethods:Set(r, g, b, a)
  self.Value = ImColor(r, g, b, a).Value
end

function ImColorMethods:SetFloat4(r, g, b, a)
  self.Value = ImVec4(r, g, b, a or 1.0)
end

local function hsv_to_rgb(h, s, v)
  h = (h % 1.0) * 6.0
  local i = math.floor(h) % 6
  local f = h - math.floor(h)
  local p = v * (1.0 - s)
  local q = v * (1.0 - s * f)
  local t = v * (1.0 - s * (1.0 - f))
  if i == 0 then return v, t, p
  elseif i == 1 then return q, v, p
  elseif i == 2 then return p, v, t
  elseif i == 3 then return p, q, v
  elseif i == 4 then return t, p, v
  else return v, p, q end
end

function ImColorMethods:SetHSV(h, s, v, a)
  self.Value = ImColor.FromHSV(h, s, v, a).Value
end

function ImColor.FromFloat4(r, g, b, a)
  return setmetatable({ Value = ImVec4(r, g, b, a or 1.0) }, ImColorMT)
end

function ImColor.FromHSV(h, s, v, a)
  local r, g, b = hsv_to_rgb(h, s, v)
  return setmetatable({ Value = ImVec4(r, g, b, a or 1.0) }, ImColorMT)
end
ImColor.HSV = ImColor.FromHSV

ImColor.WHITE = setmetatable({ Value = ImVec4(1.0, 1.0, 1.0, 1.0) }, ImColorMT)
ImColor.BLACK = setmetatable({ Value = ImVec4(0.0, 0.0, 0.0, 1.0) }, ImColorMT)

-- PushStyleColor: старый API допускал ImU32 — конвертируем в ImVec4
local origPushStyleColor = mm.PushStyleColor
if type(origPushStyleColor) == 'function' then
  function imgui.PushStyleColor(idx, col, ...)
    if type(col) == 'number' then
      return origPushStyleColor(idx, mm.ColorConvertU32ToFloat4(bit.tobit(col)))
    end
    return origPushStyleColor(idx, col, ...)
  end
end

--------------------------------------------------------------------------------
-- Перечисления: старые имена -> имена mimgui (ImGui 1.72)
--------------------------------------------------------------------------------

local function compat_enum(mmname, renames, removed)
  local source = mm[mmname]
  if type(source) ~= 'table' then return end
  local enum = {}
  setmetatable(enum, {
    __index = function(_, key)
      local value = source[(renames and renames[key]) or key]
      if value == nil and removed ~= nil then value = removed[key] end
      if value ~= nil then enum[key] = value end -- кэшируем
      return value
    end,
  })
  imgui[mmname] = enum
end

compat_enum('Col', {
  ChildWindowBg        = 'ChildBg',
  ComboBg              = 'PopupBg',
  ModalWindowDarkening = 'ModalWindowDimBg',
  CloseButton          = 'Button',
})
compat_enum('StyleVar', {
  ChildWindowRounding = 'ChildRounding',
})
compat_enum('WindowFlags', nil, {
  ShowBorders = 0, -- удалённый флаг: без рамок в любом случае
})
compat_enum('TreeNodeFlags', {
  AllowOverlapMode = 'AllowItemOverlap',
})
compat_enum('SelectableFlags')
compat_enum('HoveredFlags')
compat_enum('InputTextFlags')
compat_enum('ColorEditFlags')
compat_enum('Cond')
compat_enum('MouseCursor', {
  Move = 'ResizeAll',
})
compat_enum('Key')
compat_enum('Dir')

imgui.InputDeviceType = { Keyboard = 1, Mouse = 2 }

--------------------------------------------------------------------------------
-- Кадровый цикл: Process / RenderInMenu / OnDrawFrame / BeforeDrawFrame
--------------------------------------------------------------------------------

imgui.Process      = false
imgui.RenderInMenu = false
imgui.LockPlayer   = false
imgui.ShowCursor   = true
imgui.DisableInput = false
imgui._VERSION     = 'MoonImGui 1.1.5 (MonetLoader compat)'

local sub
sub = mm.OnFrame(
  function()
    return imgui.Process and (imgui.RenderInMenu or not isPauseMenuActive())
  end,
  function()
    sub.LockPlayer  = (imgui.LockPlayer or imgui.DisableInput) == true
    sub.HideCursor  = not imgui.ShowCursor
    if imgui.BeforeDrawFrame then imgui.BeforeDrawFrame() end
  end,
  function()
    if imgui.OnDrawFrame then imgui.OnDrawFrame() end
  end)

--------------------------------------------------------------------------------
-- Текстуры, шрифты, прочие утилиты старого API
--------------------------------------------------------------------------------

function imgui.GetContentRegionAvailWidth()
  return mm.GetContentRegionAvail().x
end

imgui.CreateTextureFromFile   = function(path) return mm.CreateTextureFromFile(path) end
imgui.CreateTextureFromMemory = function(address, size)
  return mm.CreateTextureFromFileInMemory(address, size)
end
imgui.ReleaseTexture = function(texture) return mm.ReleaseTexture(texture) end

function imgui.RebuildFonts()
  mm.InvalidateFontsTexture()
  return mm.CreateFontsTexture()
end

imgui.SwitchContext = function() return mm.SwitchContext() end
imgui.ImFontAtlasGlyphRangesBuilder = mm.ImFontGlyphRangesBuilder

-- RW-текстур игры на Android нет — старый API всегда «не находит» текстуру
imgui.GetTextureFromAddress = function() return nil end

-- всё остальное (Text, Button, Begin, GetStyle, CalcTextSize, ...)
-- берётся напрямую из mimgui
setmetatable(imgui, { __index = mm })

return imgui
