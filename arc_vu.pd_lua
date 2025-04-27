-- arc_vu.pd_lua - VU bar with modulation head & clock-driven tail
--  * skips first 3 echo-mod messages after each base change
--  * tail fades by 30 ms pd.Clock; when tail is gone, bar redraws clean
--  * identical frames are suppressed to remove flicker

------------------------------------------------------------------
-- 0. Pd binding
------------------------------------------------------------------
local pd = (function()
  local ok, m = pcall(require, "pd")
  return ok and m or assert(_G.pd, "load pdlua first")
end)()

------------------------------------------------------------------
-- 1. Class / constants
------------------------------------------------------------------
local arc_vu = pd.Class:new():register("arc_vu")

local START_LED, END_LED = 38, 26
local STEPS              = 53
local MAX                = 15
local MARKER             = 4
local DEVICE_LED         = 32
local PROJECT_LEDS       = {31, 33}

local SKIP_COUNT_DEFAULT = 3
local CLOCK_TICK_MS      = 30

------------------------------------------------------------------
-- 2. Helpers
------------------------------------------------------------------
local function clamp(v,l,h) return (v<l) and l or ((v>h) and h or v) end
local function val2led(v)
  return (START_LED + math.floor(clamp(v,0,1000)/1000*(STEPS-1)+0.5)) % 64
end
local function zeros(fill)
  local t = {}
  for i = 1,64 do t[i] = fill or 0 end
  return t
end
local function tail_live(t)
  for i = 1,64 do if t[i] > 0 then return true end end
  return false
end
local function same(a,b)
  for i = 1,64 do if a[i] ~= b[i] then return false end end
  return true
end
local function path(a,b)
  local pts = {}
  local d = (b - a + 64) % 64
  if d > 32 then d = d - 64 end
  local step = (d >= 0) and 1 or -1
  for _ = 1, math.abs(d) - 1 do
    a = (a + step) % 64
    pts[#pts + 1] = a
  end
  return pts
end

------------------------------------------------------------------
-- 3. Constructor
------------------------------------------------------------------
function arc_vu:initialize(_, atoms)
  self.ring      = clamp(tonumber(atoms[1]) or 0, 0, 3)
  self.base      = 0
  self.mode      = 0
  self.tail      = zeros()
  self.last_head = val2led(0)
  self.skip_mod  = 0
  self.prev      = zeros(-1)   -- sentinel so first frame always sends

  self.fade_clock = pd.Clock:new()
  self.fade_clock:set(self, "_tick")

  self.inlets, self.outlets = 3, 2
  self:_draw()
  return true
end

------------------------------------------------------------------
-- 4. Tail helpers and clock
------------------------------------------------------------------
function arc_vu:_fade_tail()
  local changed = false
  for i = 1,64 do
    if self.tail[i] > 0 then self.tail[i] = self.tail[i] - 1; changed = true end
  end
  return changed
end

function arc_vu:_add_head(idx)
  for _, p in ipairs(path(self.last_head, idx)) do self.tail[p+1] = MAX end
  self.tail[idx+1] = MAX
  self.last_head = idx
  self.fade_clock:delay(CLOCK_TICK_MS)
end

function arc_vu:_tick()
  if self:_fade_tail() then self:_draw() end
  if tail_live(self.tail) then
    self.fade_clock:delay(CLOCK_TICK_MS)
  else
    self.tail = zeros()
    self.prev = zeros(-1)      -- force transmission of clean VU
    self:_draw()
    self.fade_clock:unset()
  end
end

------------------------------------------------------------------
-- 5. VU bar
------------------------------------------------------------------
local function vu_bar(v)
  local leds = zeros()
  local full = math.floor((v / 1000) * (STEPS - 1))
  for i = 0, full - 1 do leds[(START_LED + i) % 64 + 1] = MAX end
  local frac = (v / 1000) * (STEPS - 1) - full
  leds[(START_LED + full) % 64 + 1] = math.floor(frac * MAX + 0.5)
  leds[START_LED + 1] = math.max(leds[START_LED + 1], MARKER)
  leds[END_LED   + 1] = math.max(leds[END_LED   + 1], MARKER)
  return leds
end

------------------------------------------------------------------
-- 6. Draw with frame deduplication
------------------------------------------------------------------
function arc_vu:_draw()
  local leds = vu_bar(self.base)

  for i = 1,64 do
    if self.tail[i] > 0 then leds[i] = self.tail[i] end
  end
  if tail_live(self.tail) then leds[val2led(self.base) + 1] = MAX end

  if self.mode == 0 then
    leds[DEVICE_LED + 1] = math.max(leds[DEVICE_LED + 1], 10)
  else
    for _, l in ipairs(PROJECT_LEDS) do leds[l + 1] = math.max(leds[l + 1], 13) end
  end

  if same(leds, self.prev) then return end
  self.prev = { table.unpack(leds) }

  self:outlet(2, "list", leds)
  self:outlet(1, "float", { self.ring })
end

------------------------------------------------------------------
-- 7. Inlets
------------------------------------------------------------------
-- 1) base value
function arc_vu:in_1_float(f)
  self.fade_clock:unset()
  self.tail     = zeros()
  self.skip_mod = SKIP_COUNT_DEFAULT
  self.prev     = zeros(-1)
  self.base     = clamp(math.floor(f or 0), 0, 1000)
  self:_draw()
end

-- 2) mode toggle
function arc_vu:in_2_float(f)
  local m = (f ~= 0) and 1 or 0
  if m ~= self.mode then self.mode = m end
  self:_draw()
end

-- 3) modulation ABS value; 99999 clears
function arc_vu:in_3_float(f)
  if math.abs(f or 0) == 99999 then
    self.tail     = zeros()
    self.prev     = zeros(-1)
    self.fade_clock:unset()
    self.skip_mod = 0
    self:_draw()
    return
  end

  if self.skip_mod > 0 then
    self.skip_mod = self.skip_mod - 1
    return
  end

  self:_fade_tail()
  local abs = clamp(math.floor(f or 0), 0, 1000)
  self:_add_head(val2led(abs))
  self:_draw()
end

return arc_vu
