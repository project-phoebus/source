-- mame_boot_dn3500.lua - drive MAME's DN3500 (SAU7) from power-on: the
-- PROM boots the disk itself; the harness only types on the keyboard and
-- watches.  Driven by mame_boot_dn3500.py through environment variables:
--   DN_SYMS        "addr T name" lines for naming PCs
--   DN_STOPS       comma list of addresses: a register/stack dump (STOP)
--   DN_PROGRESS    comma list of addresses: a one-line PROGRESS
--   DN_RAW_BPS     '|'-separated raw bpset arguments
--   DN_CONSOLE     the PROM's console output routine (0x2142, PROM entry
--                  0x108; character in D1): each character is collected
--                  for the stages' expects and written to DN_OUT/console.txt
--   DN_STAGES      stages separated by \31; a stage is
--                  "WAIT\30EXPECT\30TEXT": typed once the console has
--                  printed EXPECT since the previous stage was typed (empty:
--                  no condition), at least WAIT frames after the previous
--                  stage, and once the CPU idles (PC in NULL_LOOP or the
--                  same PC for 30 frames) or 300 frames after the rest held
--   DN_CALENDAR    "yy,mo,dd,wday,hh,mi,ss": written into the MC146818 at
--                  frame 1, binary 24-hour mode, as CAL_$WRITE_CALENDAR does
--   DN_FRAMES      the frame budget
--   DN_FINISH_ON   end the run once the console has printed this
--   DN_FINISH_AFTER end the run this many frames after the last stage
--   DN_SNAP_EVERY  a snapshot every N frames (0: none); always one at the end
--   DN_PCBS        PCBS's address: at the end, each process's PCB chain
--   DN_KEY_HOLD / DN_KEY_GAP  frames a key is held / released (4 / 4)
-- Needs -debug -debugger none.

local out_dir = os.getenv("DN_OUT") or "."
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local dbg = manager.machine.debugger

local function log(fmt, ...) print(string.format("BOOT " .. fmt, ...)) end

local syms = {}
for line in io.lines(os.getenv("DN_SYMS")) do
  local a, n = line:match("^(%x+)%s+%S%s+(%S+)$")
  if a then syms[#syms + 1] = { tonumber(a, 16), n } end
end
table.sort(syms, function(x, y) return x[1] < y[1] end)
local function nearest(pc)
  if pc < 0x10000 then return string.format("PROM+0x%X", pc) end
  local best
  for _, s in ipairs(syms) do
    if s[1] <= pc then best = s else break end
  end
  if not best or pc - best[1] > 0x10000 then return "?" end
  return string.format("%s+0x%X", best[2], pc - best[1])
end
local null_loop = nil
for _, s in ipairs(syms) do if s[2] == "NULL_LOOP" then null_loop = s[1] end end
local function split(s)
  local t = {}
  for v in (s or ""):gmatch("[^,]+") do t[#t + 1] = tonumber(v) end
  return t
end

local run_frames = tonumber(os.getenv("DN_FRAMES") or "36000")
local snap_every = tonumber(os.getenv("DN_SNAP_EVERY") or "0")
local finish_on = os.getenv("DN_FINISH_ON") or ""
local finish_after = tonumber(os.getenv("DN_FINISH_AFTER") or "-1")
local KEY_HOLD = tonumber(os.getenv("DN_KEY_HOLD") or "") or 4
local KEY_GAP = tonumber(os.getenv("DN_KEY_GAP") or "") or 4

local function regdump_action(name)
  local regs = "pc=%08X sr=%04X sp=%08X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X"
  local args = "pc,sr,sp,d0,d1,d2,d3,d4,d5,d6,d7,a0,a1,a2,a3,a4,a5,a6"
  local stk, sargs = "", ""
  for i = 0, 11 do
    stk = stk .. " %08X"
    sargs = sargs .. string.format(",d@(sp+%d)", i * 4)
  end
  return string.format('{logerror "STOP %s %s stack:%s\\n",%s%s;go}', name, regs, stk, args, sargs)
end

local console_addr = tonumber(os.getenv("DN_CONSOLE") or "")
local function set_breakpoints()
  -- the 3C505 has its own CPU: the debugger's commands must address ours
  dbg:command("focus :maincpu")
  if console_addr then
    dbg:command(string.format('bpset 0x%X,1,{printf "CON%%02X\\n",(d1&0xff);go}', console_addr))
  end
  for _, a in ipairs(split(os.getenv("DN_STOPS"))) do
    dbg:command(string.format("bpset 0x%X,1,%s", a, regdump_action(nearest(a))))
  end
  for _, a in ipairs(split(os.getenv("DN_PROGRESS"))) do
    dbg:command(string.format('bpset 0x%X,1,{logerror "PROGRESS %s pc=%%08X sp=%%08X\\n",pc,sp;go}', a, nearest(a)))
  end
  for raw in (os.getenv("DN_RAW_BPS") or ""):gmatch("[^|]+") do
    dbg:command("bpset " .. raw)
  end
end

local function set_calendar()
  local cal = {}
  for v in (os.getenv("DN_CALENDAR") or ""):gmatch("[^,]+") do cal[#cal + 1] = tonumber(v) end
  if #cal == 7 then
    -- the MC146818's registers are the bytes at 0x10900 + n
    local function rtc(reg, val) mem:write_u8(0x10900 + reg, val) end
    rtc(10, 0x20); rtc(11, 0x86)
    for k, reg in ipairs({ 9, 8, 7, 6, 4, 2, 0 }) do rtc(reg, cal[k]) end
    rtc(11, 6)
    log("calendar %02d-%02d-%02d (weekday %d) %02d:%02d:%02d, binary; reads back year=%d month=%d day=%d hour=%d",
        cal[1], cal[2], cal[3], cal[4], cal[5], cal[6], cal[7],
        mem:read_u8(0x10909), mem:read_u8(0x10908), mem:read_u8(0x10907), mem:read_u8(0x10904))
  end
end

-- the console
local con_file = io.open(out_dir .. "/console.txt", "wb")
local con_text, con_seen, finish_seen = "", 0, false
local function con_poll()
  local cl = dbg.consolelog
  local n = #cl
  local chunk = {}
  for i = math.max(con_seen + 1, n - 4000), n - 1 do
    local line = cl[i] or ""
    for hex in line:gmatch("CON(%x%x)") do chunk[#chunk + 1] = string.char(tonumber(hex, 16) & 0x7F) end
    con_seen = i
  end
  if #chunk > 0 then
    local s = table.concat(chunk)
    con_file:write(s)
    con_file:flush()
    con_text = con_text .. s
    if finish_on ~= "" and con_text:find(finish_on, 1, true) then finish_seen = true end
    con_text = con_text:sub(-2000)
  end
end

-- the keyboard (apollo_kbd): a key's field by its name's first token,
-- Return by its mask (keyboard1 0x20000000), Space by name; a capital
-- letter or a shifted character with Shift; ^A..^Z with Ctrl
local function kbd_field(tag, pred)
  for t, port in pairs(manager.machine.ioport.ports) do
    if t:match(tag .. "$") then
      for name, field in pairs(port.fields) do
        if pred(name, field) then return field end
      end
    end
  end
  return nil
end
local SHIFTED = { ["!"] = "1", ['"'] = "2", ["#"] = "3", ["$"] = "4", ["%"] = "5", ["&"] = "6", ["'"] = "7",
  ["("] = "8", [")"] = "9", ["_"] = "-", ["+"] = "=", ["<"] = ",", [">"] = ".", ["?"] = "/", ["|"] = "\\",
  ["{"] = "[", ["}"] = "]" }
local function char_keys(ch)
  local b = ch:byte()
  if b >= 1 and b <= 26 and ch ~= "\r" then
    local want = string.char(b + 64)
    return kbd_field(":keyboard%d", function(n) return n:match("^(%S+)") == want end),
           kbd_field(":keyboard4", function(_, fl) return fl.mask == 0x4 end)
  end
  local shift, key = nil, ch
  if ch:match("%u") then shift = true
  elseif SHIFTED[ch] then shift, key = true, SHIFTED[ch] end
  local f
  if ch == "\r" then
    f = kbd_field(":keyboard1", function(_, fl) return fl.mask == 0x20000000 end)
  elseif ch == " " then
    f = kbd_field(":keyboard%d", function(n) return n:lower() == "space" end)
  else
    local want = key:upper()
    f = kbd_field(":keyboard%d", function(n) return n:match("^(%S+)") == want end)
  end
  -- the two Shift fields share a name, so only one (0x20, the right Shift)
  -- survives in port.fields
  return f, shift and kbd_field(":keyboard4", function(n, fl) return fl.mask == 0x2 or fl.mask == 0x20 end) or nil
end

local stages = {}
for st in (os.getenv("DN_STAGES") or ""):gmatch("[^\31]+") do
  local w, bang, e, t = st:match("^(%d*)(!?)\30(.-)\30(.*)$")
  stages[#stages + 1] = { wait = tonumber(w) or 0, force = bang == "!", expect = e, text = t }
end
local frames, last_typed, expect_met_at = 0, 0, -1
local key_queue, key_state, key_wait = {}, "idle", 0
local last_pc, same_count, history = -1, 0, {}
local stages_done_at = (#stages == 0) and 0 or -1

local function queue_text(text)
  for ch in text:gmatch(".") do
    local f, sh = char_keys(ch)
    if f then key_queue[#key_queue + 1] = { f, sh } else log("no key for %q", ch) end
  end
end
local IDLE_TIMEOUT = tonumber(os.getenv("DN_IDLE_TIMEOUT") or "") or 300
local IDLE_FRAMES = tonumber(os.getenv("DN_IDLE_FRAMES") or "") or 60
local idle_count = 0
local function idle(pc)
  return idle_count >= IDLE_FRAMES or same_count >= 30
end
local function stage_step(pc)
  if #key_queue > 0 or #stages == 0 then return end
  local st = stages[1]
  if frames < last_typed + st.wait then return end
  if st.expect ~= "" and not con_text:find(st.expect, 1, true) then return end
  if expect_met_at < 0 then expect_met_at = frames end
  -- "N!" waits: no idle needed; an expect: idle, or IDLE_TIMEOUT frames
  -- after it was met; otherwise idle only
  if not st.force and not idle(pc) and (st.expect == "" or frames < expect_met_at + IDLE_TIMEOUT) then return end
  table.remove(stages, 1)
  log("stage: typing %q at frame %d (pc=%08X %s)", st.text, frames, pc, nearest(pc))
  manager.machine.video:snapshot()
  queue_text(st.text)
  last_typed, expect_met_at = frames, -1
  con_text = ""
  if #stages == 0 then stages_done_at = frames end
end
local function key_step()
  if key_wait > 0 then key_wait = key_wait - 1 return end
  if key_state == "down" then
    key_queue[1][1]:clear_value()
    if key_queue[1][2] then key_queue[1][2]:clear_value() end
    table.remove(key_queue, 1)
    key_state, key_wait = "idle", KEY_GAP
  elseif #key_queue > 0 then
    if key_queue[1][2] then key_queue[1][2]:set_value(1) end
    key_queue[1][1]:set_value(1)
    key_state, key_wait = "down", KEY_HOLD
  end
end

local finished = false
local function finish(reason)
  if finished then return end
  finished = true
  con_poll()
  log("finish: %s after %d frames", reason, frames)
  dbg:command("bplist")
  local cl = dbg.consolelog
  local df = io.open(out_dir .. "/debugger_console.txt", "w")
  for i = 1, #cl do df:write(tostring(cl[i]) .. "\n") end
  df:close()
  local pc = cpu.state["PC"].value
  log("pc=%08X (%s) sr=%04X sp=%08X", pc, nearest(pc), cpu.state["SR"].value, cpu.state["SP"].value)
  local r = {}
  for i = 0, 7 do r[#r + 1] = string.format("D%d=%08X", i, cpu.state["D" .. i].value) end
  print(table.concat(r, " "))
  r = {}
  for i = 0, 7 do r[#r + 1] = string.format("A%d=%08X", i, cpu.state["A" .. i].value) end
  print(table.concat(r, " "))
  local hist = {}
  for i = math.max(1, #history - 30), #history do hist[#hist + 1] = string.format("%X(%s)", history[i], nearest(history[i])) end
  log("pc per frame (last %d): %s", #hist, table.concat(hist, " "))
  local pcbs = tonumber(os.getenv("DN_PCBS") or "")
  if pcbs then
    for pid = 0, 64 do
      local pcb = mem:readv_u32(pcbs + 4 * pid)
      if pcb ~= 0 and mem:readv_u32(pcb + 0x08 + 4 * 11) ~= 0 then
        local a6, a7 = mem:readv_u32(pcb + 0x08 + 4 * 10), mem:readv_u32(pcb + 0x08 + 4 * 11)
        local chain, fp = {}, a6
        for _ = 1, 10 do
          if fp == 0 or fp % 2 ~= 0 then break end
          local ret = mem:readv_u32(fp + 4)
          chain[#chain + 1] = string.format("%X(%s)", ret, nearest(ret))
          fp = mem:readv_u32(fp)
        end
        log("pcb %d at %08X flags=%04X a6=%08X a7=%08X: %s", pid, pcb, mem:readv_u16(pcb + 0x54), a6, a7,
            table.concat(chain, " "))
      end
    end
  end
  manager.machine.video:snapshot()
  con_file:close()
  manager.machine:exit()
end

emu.register_frame_done(function()
  if finished then return end
  frames = frames + 1
  if frames == 1 then
    set_calendar()
    set_breakpoints()
  end
  con_poll()
  local pc = cpu.state["PC"].value
  history[#history + 1] = pc
  if #history > 200 then table.remove(history, 1) end
  if pc == last_pc then same_count = same_count + 1 else same_count = 0 end
  if null_loop and pc >= null_loop and pc < null_loop + 0x40 then idle_count = idle_count + 1 else idle_count = 0 end
  last_pc = pc
  stage_step(pc)
  key_step()
  if snap_every > 0 and frames % snap_every == 0 then manager.machine.video:snapshot() end
  if frames % 3000 == 0 then log("frame %d pc=%08X (%s)", frames, pc, nearest(pc)) end
  if finish_seen and #stages == 0 and #key_queue == 0 then finish("the console showed the finish text") return end
  if finish_after >= 0 and stages_done_at >= 0 and #key_queue == 0 and frames >= stages_done_at + finish_after then
    finish("finish-after frames since the last stage") return
  end
  if frames >= run_frames then finish("frame budget exhausted") end
end)
