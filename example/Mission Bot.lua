-- MonetLoader 3.8.0
-- Mission Bot — автоматический помощник прохождения миссий.
--
-- Что умеет:
--   * Автостарт миссий: находит ближайший маркер миссии на радаре и
--     телепортирует туда игрока (маркер срабатывает сам), либо доходит/доезжает сам;
--   * Автопилот: ведёт игрока к цели (бегом, или на машине: газ/тормоз/руль);
--   * Во время миссии следит за блипом цели и едет/идёт к ней;
--   * Боевой ассистент: убивает всех педов в радиусе (по умолчанию ВЫКЛ —
--     может убить сюжетного союзника и сорвать миссию!);
--   * God mode (неуязвимость) и выдача оружия при старте миссии.
--
-- Важно понимать: универсального ИИ, который понимает ЛЮБЫЕ цели миссий
-- (у SA миссии — произвольные скрипты в main.scm), не существует даже на PC —
-- там используются трюки вида 0417:start_mission/$ONMISSION. Этот бот делает
-- за игрока «черновую» работу: старт миссий, дорога до цели, бой, выживание.
--
-- Управление: плавающая кнопка «BOT» на экране -> окно настроек.
-- В SAMP доступна команда /mbot.
--
-- Калибровка: если бот рулит в противоположную сторону — см. cfg.steer_sign
-- (поставьте -1). Если бежит назад — cfg.forward_sign = 1.

script_name('Mission Bot')
script_version('1.0')
script_version_number(1)
script_author('MonetLoader OSS')
script_description('Auto mission starter, autopilot and combat assistant.')

local imgui = require 'mimgui'
local ffi = require 'ffi'

----------------------------------------------------------------------
-- КОНФИГУРАЦИЯ
----------------------------------------------------------------------
local cfg = {
  enabled         = false, -- главный выключатель автоматики
  auto_start      = true,  -- самому находить и стартовать миссии
  use_teleport    = true,  -- телепорт к маркеру (иначе бот идёт/едет сам)
  objective_pilot = true,  -- во время миссии двигаться к блипу цели
  combat          = false, -- боевой ассистент (ОСТОРОЖНО: ломает миссии с союзниками)
  combat_radius   = 40.0,
  combat_skip_cars = true, -- не трогать педов в машинах
  god_mode        = false,
  auto_weapon     = true,  -- выдавать оружие при старте миссии
  weapon_id       = 24,    -- Desert Eagle
  weapon_ammo     = 500,
  max_speed       = 26.0,  -- ограничение скорости автопилота (м/с)
  stop_radius     = 14.0,  -- «приехали», когда до цели ближе этого
  steer_sign      = 1,     -- калибровка поворота: 1 или -1
  forward_sign    = -1,    -- калибровка «стик вперёд»: -1 или 1
}

-- состояние бота (для UI и отладки; менять можно и из консоли: mission_bot.cfg)
local B = {
  cfg = cfg,
  state = 'OFF',      -- OFF / IDLE / GOING / WAIT_START / IN_MISSION / COOLDOWN
  missions_started = 0,
  missions_finished = 0,
  kills = 0,
  attempts = 0,
  last_blip_slot = -1,
  status = 'выключен',
  target = nil,       -- { x=, y=, z= }
}
mission_bot = B -- глобальный доступ для отладки/тестов

----------------------------------------------------------------------
-- УТИЛИТЫ
----------------------------------------------------------------------
local function now()
  return os.clock()
end

local last_call = {}
local function every(interval, key)
  key = key or '?'
  local t = now()
  if last_call[key] == nil or t - last_call[key] >= interval then
    last_call[key] = t
    return true
  end
  return false
end

local function dist2d(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

local function norm_angle(a)
  return (a + math.pi) % (2 * math.pi) - math.pi
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- опущенный стик/кнопки: вызывать, когда бот не управляет игроком
local pad_dirty = false
local function pad_reset()
  if not pad_dirty then return end
  setPadButtonState('leftx', 0)
  setPadButtonState('lefty', 0)
  setPadButtonState('cross', 0)
  setPadButtonState('square', 0)
  setPadButtonState('triangle', 0)
  pad_dirty = false
end

local function pad_set(name, value)
  pad_dirty = true
  setPadButtonState(name, value)
end

----------------------------------------------------------------------
-- БЛИПЫ РАДАРА
----------------------------------------------------------------------
local function get_waypoint()
  local ok, x, y = getTargetBlipCoordinates()
  if ok and x ~= nil and y ~= nil then return x, y end
  return nil
end

-- все координатные блипы, кроме пользовательской метки (waypoint)
local function coord_blips()
  local res = {}
  local wx, wy = get_waypoint()
  for _, b in ipairs(getRadarBlips()) do
    if b.type == 2 then -- координатный блип
      if wx == nil or (math.abs(b.x - wx) > 2.0 or math.abs(b.y - wy) > 2.0) then
        res[#res + 1] = b
      end
    end
  end
  return res
end

local function nearest_blip(ped)
  local px, py = getCharCoordinates(ped)
  local best, best_d = nil, math.huge
  for _, b in ipairs(coord_blips()) do
    local d = dist2d(px, py, b.x, b.y)
    if d < best_d then
      best, best_d = b, d
    end
  end
  return best, best_d
end

----------------------------------------------------------------------
-- АВТОПИЛОТ
----------------------------------------------------------------------
local function pilot(ped, tx, ty)
  local x, y = getCharCoordinates(ped)
  local dx, dy = tx - x, ty - y
  local want = math.atan2(dx, dy)
  local h = getCharHeading(ped)
  local diff = norm_angle(want - h) * cfg.steer_sign
  local steer = clamp(diff * 2.5, -1.0, 1.0)
  local dist = math.sqrt(dx * dx + dy * dy)

  if isCharSittingInAnyCar(ped) then
    local car = storeCarCharIsInNoSave(ped)
    local speed = car ~= 0 and car ~= -1 and getCarSpeed(car) or 0
    pad_set('leftx', math.floor(steer * 128))

    local gas, brake = 255, 0
    if math.abs(diff) > 1.1 then -- крутой поворот: сбрасываем газ
      gas = 0
      brake = 255
    end
    if speed > cfg.max_speed then
      gas = 0
    end
    if dist < cfg.stop_radius then -- приехали: тормозим
      gas, brake = 0, 255
    end
    pad_set('cross', gas)
    pad_set('square', brake)
    return dist
  end

  -- пешком
  pad_set('leftx', math.floor(steer * 128))
  pad_set('lefty', math.floor(128 * cfg.forward_sign))
  pad_set('cross', 255) -- спринт (удержание)

  -- далеко и рядом стоит машина — садимся и продолжим на ней
  if dist > 60.0 then
    local vx, vy, vz
    local best_c, best_d = nil, 9.0
    for _, v in ipairs(getAllVehicles()) do
      vx, vy, vz = getCarCoordinates(v)
      local d = dist2d(x, y, vx, vy)
      if d < best_d then
        best_c, best_d = v, d
      end
    end
    if best_c ~= nil and best_d < 8.0 then
      pad_set('triangle', 255) -- держим «сесть в машину»
    end
  end
  return dist
end

----------------------------------------------------------------------
-- ПОДСИСТЕМЫ
----------------------------------------------------------------------
local function combat_tick(ped)
  local px, py = getCharCoordinates(ped)
  for _, h in ipairs(getAllChars()) do
    if h ~= ped and not isCharDead(h) then
      if not (cfg.combat_skip_cars and isCharSittingInAnyCar(h)) then
        local hx, hy = getCharCoordinates(h)
        if dist2d(px, py, hx, hy) <= cfg.combat_radius then
          setCharHealth(h, 0.0)
          B.kills = B.kills + 1
        end
      end
    end
  end
end

local function god_tick(ped)
  setCharProofs(ped, true, true, true, true, true)
  setCharHealth(ped, 100.0)
end

local function teleport(ped, blip)
  setCharCoordinates(ped, blip.x, blip.y, blip.z + 1.0)
end

----------------------------------------------------------------------
-- КОНЕЧНЫЙ АВТОМАТ
----------------------------------------------------------------------
local deadline = 0

local function state_machine(ped)
  local t = now()

  if B.state == 'IDLE' then
    local blip, d = nearest_blip(ped)
    B.target = blip
    if blip == nil then
      B.status = 'маркеров миссий не видно'
      return
    end
    B.status = ('цель: маркер (%.0f м)'):format(d)
    if cfg.use_teleport then
      teleport(ped, blip)
      B.last_blip_slot = blip.slot
      B.state = 'WAIT_START'
      B.attempts = B.attempts + 1
      deadline = t + 8.0
    else
      B.state = 'GOING'
    end

  elseif B.state == 'GOING' then
    local blip = nearest_blip(ped)
    if blip == nil then
      B.state = 'IDLE'
      return
    end
    B.target = blip
    local d = pilot(ped, blip.x, blip.y)
    B.status = ('иду/еду к цели: %.0f м'):format(d)
    if d <= 2.5 then
      pad_reset()
      B.state = 'WAIT_START'
      B.attempts = B.attempts + 1
      deadline = t + 8.0
    end

  elseif B.state == 'WAIT_START' then
    pad_reset()
    B.status = 'жду начала миссии...'
    local started = isPlayerControlLocked()
    local blip = nearest_blip(ped)
    if started or blip == nil then
      B.state = 'IN_MISSION'
      B.missions_started = B.missions_started + 1
      if cfg.auto_weapon then
        giveWeaponToChar(ped, cfg.weapon_id, cfg.weapon_ammo)
      end
      printStringNow('~g~Mission Bot: mission started', 1500)
    elseif t > deadline then
      -- маркер не сработал (интерьер/недоступен): пауза и новая попытка
      B.state = 'COOLDOWN'
      deadline = t + 3.0
      if B.attempts >= 3 then
        B.status = 'маркер недоступен, пробую другой'
        B.last_blip_slot = -1
        B.attempts = 0
      end
    end

  elseif B.state == 'IN_MISSION' then
    local blip = nearest_blip(ped)
    B.target = blip
    if blip ~= nil and cfg.objective_pilot and not isPlayerControlLocked() then
      local d = pilot(ped, blip.x, blip.y)
      B.status = ('миссия: к цели %.0f м'):format(d)
    else
      pad_reset()
      B.status = 'в миссии (катсцена/бой)'
    end
    -- конец миссии: управление вернули и цели на радаре нет
    if not isPlayerControlLocked() and blip == nil then
      if B._end_since == nil then
        B._end_since = t
      elseif t - B._end_since > 4.0 then
        B._end_since = nil
        B.missions_finished = B.missions_finished + 1
        B.state = 'COOLDOWN'
        deadline = t + 4.0
        printStringNow('~y~Mission Bot: mission over', 1500)
      end
    else
      B._end_since = nil
    end

  elseif B.state == 'COOLDOWN' then
    pad_reset()
    B.status = 'пауза'
    if t > deadline then
      B.state = 'IDLE'
    end
  end
end

----------------------------------------------------------------------
-- ГЛАВНЫЙ ТИК
----------------------------------------------------------------------
function B.tick()
  if not cfg.enabled then
    if B.state ~= 'OFF' then
      pad_reset()
      B.state = 'OFF'
      B.status = 'выключен'
    end
    return
  end

  if isPauseMenuActive() then
    return
  end

  local ped = PLAYER_PED
  if ped == nil or ped == -1 or isCharDead(ped) then
    B.state = 'IDLE' -- умер/ещё не заспавнился
    pad_reset()
    return
  end

  if cfg.god_mode and every(1.0, 'god') then
    god_tick(ped)
  end

  if cfg.combat and every(0.3, 'combat') then
    combat_tick(ped)
  end

  if B.state == 'OFF' then
    B.state = 'IDLE'
  end

  if cfg.auto_start or B.state == 'IN_MISSION' then
    state_machine(ped)
  else
    pad_reset()
  end
end

----------------------------------------------------------------------
-- ПОЛЬЗОВАТЕЛЬСКИЙ ИНТЕРФЕЙС (mimgui)
----------------------------------------------------------------------
local ui = {
  visible = false,
  combat = ffi.new('bool[1]', cfg.combat),
  god = ffi.new('bool[1]', cfg.god_mode),
  auto_start = ffi.new('bool[1]', cfg.auto_start),
  teleport = ffi.new('bool[1]', cfg.use_teleport),
  objective = ffi.new('bool[1]', cfg.objective_pilot),
  weapon = ffi.new('bool[1]', cfg.auto_weapon),
  radius = ffi.new('float[1]', cfg.combat_radius),
}

local function sync_cfg()
  cfg.combat = ui.combat[0]
  cfg.god_mode = ui.god[0]
  cfg.auto_start = ui.auto_start[0]
  cfg.use_teleport = ui.teleport[0]
  cfg.objective_pilot = ui.objective[0]
  cfg.auto_weapon = ui.weapon[0]
  cfg.combat_radius = ui.radius[0]
end

-- плавающая кнопка включения интерфейса
imgui.OnFrame(function() return not ui.visible end, function()
  imgui.SetNextWindowPos(imgui.ImVec2(8, 260), imgui.Cond.FirstUseEver)
  if imgui.Begin('MissionBotToggle', nil,
      imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize
      + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoBackground) then
    if imgui.Button('BOT', imgui.ImVec2(64, 48)) then
      ui.visible = true
    end
  end
  imgui.End()
end)

-- основное окно
imgui.OnFrame(function() return ui.visible end, function()
  imgui.SetNextWindowPos(imgui.ImVec2(40, 150), imgui.Cond.FirstUseEver)
  if imgui.Begin('Mission Bot v1.0', nil, imgui.WindowFlags.AlwaysAutoResize) then
    if imgui.Button(cfg.enabled and 'СТОП' or 'ПУСК', imgui.ImVec2(-1, 44)) then
      cfg.enabled = not cfg.enabled
      if not cfg.enabled then
        B._end_since = nil
      end
    end

    imgui.Separator()
    imgui.Checkbox('Автостарт миссий', ui.auto_start)
    imgui.Checkbox('Телепортом (иначе автопилот)', ui.teleport)
    imgui.Checkbox('Автопилот к цели миссии', ui.objective)
    imgui.Checkbox('Выдавать оружие', ui.weapon)
    imgui.Checkbox('God mode', ui.god)
    imgui.Checkbox('Боевой ассистент (опасно!)', ui.combat)
    if ui.combat[0] then
      imgui.SliderFloat('Радиус боя', ui.radius, 10.0, 100.0, '%.0f м')
      imgui.TextColored(imgui.ImVec4(1, 0.4, 0.4, 1), 'убивает ВСЕХ педов рядом, включая союзников')
    end

    imgui.Separator()
    imgui.Text(('Состояние: %s'):format(B.state))
    imgui.Text(B.status)
    imgui.Text(('Миссий запущено: %d, завершено: %d'):format(B.missions_started, B.missions_finished))
    imgui.Text(('Убито ботом: %d'):format(B.kills))

    if imgui.Button('Свернуть', imgui.ImVec2(-1, 36)) then
      sync_cfg()
      ui.visible = false
    end
  end
  imgui.End()
end)

----------------------------------------------------------------------
-- ТОЧКА ВХОДА
----------------------------------------------------------------------
function main()
  if isSampLoaded() and isSampfuncsLoaded() then
    while not isSampAvailable() do
      wait(100)
    end
    sampRegisterChatCommand('mbot', function()
      cfg.enabled = not cfg.enabled
      sampAddChatMessage(('Mission Bot: %s'):format(cfg.enabled and 'включен' or 'выключен'), 0x33AA33)
    end)
  end

  while true do
    wait(0)
    local ok, err = pcall(B.tick)
    if not ok then
      B.status = 'ошибка: ' .. tostring(err)
      B.state = 'IDLE'
      pad_reset()
      wait(1000)
    end
  end
end

function onScriptTerminate(scr)
  if scr == script.this then
    cfg.enabled = false
    pad_reset()
    if PLAYER_PED ~= nil and PLAYER_PED ~= -1 then
      setCharProofs(PLAYER_PED, false, false, false, false, false)
    end
  end
end
