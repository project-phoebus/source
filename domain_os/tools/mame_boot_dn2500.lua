-- mame_boot_dn2500.lua - take the DN2500's MD9 PROM to its prompt, then
-- load an SAU9 RFC image into RAM the way sysboot would and start
-- COLD_START.  Driven by mame_boot_dn2500.py through environment variables:
--   DN_IMAGE      the RFC image (dist/sau9/domain_os)
--   DN_SYMS       "addr T name" lines for naming PCs
--   DN_STOPS      comma list of addresses to log a register/stack dump at
--   DN_PROGRESS   comma list of addresses to log a one-line PROGRESS at
--   DN_FLAGS      the boot flags word (D2's low word)
--   DN_RECORD     the PROM's configuration record (A2)
--   DN_MEM_LIMIT  stored at the record's +4, COLD's memory limit
--   DN_FRAMES     frames to run after entry
--   DN_PROM_FRAMES frames the PROM may take to reach its prompt
--   DN_STUCK_FRAMES frames the PC may stay put before the run ends
--   DN_RAW_BPS    '|'-separated raw bpset arguments
--   DN_RAW_WPS    '|'-separated raw wpset arguments
--   DN_PROM_WPS   the same, set at the first frame (the PROM's tests)
--   DN_NORMAL_MODE set: the mode switch at normal (the PROM boots without
--                 its service-mode prompt; the harness's cfg sets it too)
--   DN_PROM_BOOT  set: the PROM boots the disk itself (the harness answers
--                 `y'); nothing is loaded, the breakpoints are set at once
--   DN_CALENDAR   "year mod 100,month,day,weekday,hour,minute,second" for the calendar
--   DN_PCBS       PCBS's address: at the end, each process's PCB and saved frame chain
--   DN_MONITOR    none (the default), 1280x1024 or 1024x800
--   DN_TYPE       "text|text": each typed on the keyboard once the machine
--                 has waited for input 60 frames (the PROM's console input
--                 loop, or the kernel's NULL_LOOP)
--   DN_KEYS       "frame:text|frame:text": typed on the keyboard from that
--                 many frames after power-on (the display console's input)
--   DN_FB_DUMP    a file for the frame buffer at the end (PBM, 2048 x 1024)
--   DN_TRACE_AFTER, DN_TRACE_FRAMES  a CPU trace to DN_OUT/trace.txt
-- Needs -debug -debugger none.  The PROM runs with the MMU off (TC = 0) at
-- its prompt, so the program space is physical when the image is placed.

local out_dir = os.getenv("DN_OUT") or "."
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local dbg = manager.machine.debugger

local function log(fmt, ...) print(string.format("BOOT " .. fmt, ...)) end

-- the configuration: the mode switch (service: the power-up tests, then
-- the prompt) and the monitor (none: the PROM's console is then the first
-- serial line it hears a CR on, SIO1, the null modem)
local port = manager.machine.ioport.ports[":CONFIG"]
local monitors = { none = 0x30, ["1280x1024"] = 0x10, ["1024x800"] = 0x00 }
port.fields["Monitor"].user_value = monitors[os.getenv("DN_MONITOR") or "none"] or 0x30
-- (the harness also writes both into the cfg, which MAME reads before the
-- first reset: the PROM reads the mode switch there)
port.fields["Mode switch"].user_value = (os.getenv("DN_NORMAL_MODE") or "") ~= "" and 0x00 or 0x01

local syms = {}
for line in io.lines(os.getenv("DN_SYMS")) do
  local a, n = line:match("^(%x+)%s+%S%s+(%S+)$")
  if a then syms[#syms + 1] = { tonumber(a, 16), n } end
end
table.sort(syms, function(x, y) return x[1] < y[1] end)
local function nearest(pc)
  local best
  for _, s in ipairs(syms) do
    if s[1] <= pc then best = s else break end
  end
  if pc < 0x20000 then return string.format("PROM+0x%X", pc) end
  if not best or pc - best[1] > 0x10000 then return "?" end
  return string.format("%s+0x%X", best[2], pc - best[1])
end
local function split(s)
  local t = {}
  for v in (s or ""):gmatch("[^,]+") do t[#t + 1] = tonumber(v) end
  return t
end

local image = assert(io.open(os.getenv("DN_IMAGE"), "rb")):read("a")
local load_addr, start_addr = string.unpack(">I4I4", image, 1)
local machine_type = string.unpack(">I2", image, 9)
local record = tonumber(os.getenv("DN_RECORD"))
local mem_limit = tonumber(os.getenv("DN_MEM_LIMIT"))
local flags = tonumber(os.getenv("DN_FLAGS") or "8")
local run_frames = tonumber(os.getenv("DN_FRAMES") or "3600")
local prom_frames = tonumber(os.getenv("DN_PROM_FRAMES") or "120000")
local prom_boot = (os.getenv("DN_PROM_BOOT") or "") ~= ""
local stuck_frames = tonumber(os.getenv("DN_STUCK_FRAMES") or "300")
local trace_after = tonumber(os.getenv("DN_TRACE_AFTER") or "-1")
local trace_frames = tonumber(os.getenv("DN_TRACE_FRAMES") or "2")

-- the Python side, which is the terminal on SIO1, creates DN_OUT/prompt
-- once the PROM's `>' prompt follows its answer to the self-test question
local prompt_flag = out_dir .. "/prompt"
os.remove(prompt_flag)
local function prompt_seen()
  local f = io.open(prompt_flag, "r")
  if f then f:close() return true end
  return false
end

local phase, frames, entered_at, prompt_at = "prom", 0, 0, -1

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

local function exc_action(a)
  -- the 68030 exception frame: sr, pc, format/vector, then its fault words
  local stk, sargs = "", ""
  for i = 0, 23 do
    stk = stk .. " %04X"
    sargs = sargs .. string.format(",w@(sp+%d)", i * 2)
  end
  return string.format('{logerror "EXC handler=%%08X sp=%%08X a5=%%08X a6=%%08X frame:%s\\n",pc,sp,a5,a6%s;go}', stk, sargs)
end

local function set_breakpoints()
  -- the PROM's vectors: all of ROM 0x8..0x3FC are 0x770 (its MD fault
  -- entry); COLD's vector page keeps them, rebased to the PROM's VA
  -- 0x3FFE0000 once the MMU is on
  for _, a in ipairs({ 0x770, 0x3FFE0770 }) do
    dbg:command(string.format("bpset 0x%X,1,%s", a, exc_action(a)))
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
  for raw in (os.getenv("DN_RAW_WPS") or ""):gmatch("[^|]+") do
    dbg:command("wpset " .. raw)
  end
end

local function set_calendar()
  -- the calendar, set as CAL_$WRITE_CALENDAR sets it: the oscillator on,
  -- SET with binary 24-hour mode, the date, SET released
  local cal = {}
  for v in (os.getenv("DN_CALENDAR") or ""):gmatch("[^,]+") do cal[#cal + 1] = tonumber(v) end
  if #cal == 7 then
    local function rtc(reg, val) mem:write_u8(0x20280, reg); mem:write_u8(0x20284, val) end
    rtc(10, 0x40); rtc(13, 0); rtc(10, 0x20); rtc(11, 0x86)
    for k, reg in ipairs({ 9, 8, 7, 6, 4, 2, 0 }) do rtc(reg, cal[k]) end
    rtc(11, 6)
    log("calendar %02d-%02d-%02d (weekday %d) %02d:%02d:%02d, binary", cal[1], cal[2], cal[3], cal[4], cal[5], cal[6], cal[7])
  end
end

local function enter()
  -- the image, all of it, at its load address (physical: the MMU is off)
  for i = 0, #image - 4, 4 do
    mem:write_u32(load_addr + i, string.unpack(">I4", image, i + 1))
  end
  for i = (#image // 4) * 4, #image - 1 do mem:write_u8(load_addr + i, image:byte(i + 1)) end
  local bad = 0
  for _, off in ipairs({ 0, 0x2000, #image - 16 }) do
    for j = 0, 15 do
      if mem:read_u8(load_addr + off + j) ~= image:byte(off + j + 1) then bad = bad + 1 end
    end
  end
  log("loaded %d bytes at %08X (start %08X, machine type %d), %d readback mismatches", #image, load_addr, start_addr, machine_type, bad)

  -- the record: COLD reads its memory limit at +4
  log("PROM record %08X before: +4=%08X +8=%08X +10=%08X +18=%08X +28=%08X +2C=%08X +34=%08X",
      record, mem:read_u32(record + 4), mem:read_u32(record + 8), mem:read_u32(record + 0x10),
      mem:read_u32(record + 0x18), mem:read_u32(record + 0x28), mem:read_u32(record + 0x2c), mem:read_u32(record + 0x34))
  mem:write_u32(record + 4, mem_limit)
  local bd = os.getenv("DN_BOOT_DEV") or ""
  if #bd == 16 then
    for k = 0, 7 do mem:write_u8(record + 0x18 + k, tonumber(bd:sub(2 * k + 1, 2 * k + 2), 16)) end
    log("boot device record +18 = %s", bd)
  end

  set_calendar()

  -- the PROM's busy flag, cleared as its resume path (0x9C0) clears it
  -- before it starts the boot program: set (from reset), the PROM's entry
  -- (0x770, the kernel's crash and console calls) would keep the caller's
  -- stack, virtual, with the MMU off
  mem:write_u8(0x40007D0, 0)

  -- the frame: return, D1, D2, A1, a word, A2
  local sp = (cpu.state["SP"].value & ~3) - 0x40
  local frame = string.pack(">I4I4I4I4I2I4I2", 0, 0, flags & 0xFFFF, 0, 0, record, 0)
  for j = 1, #frame, 2 do mem:write_u16(sp + j - 1, string.unpack(">I2", frame, j)) end
  set_breakpoints()
  cpu.state["SR"].value = 0x2700
  cpu.state["SP"].value = sp
  cpu.state["PC"].value = start_addr
  log("entry pc=%08X sp=%08X sr=%04X flags=%04X record=%08X limit=%08X", start_addr, sp, 0x2700, flags, record, mem_limit)
end

local last_pc, same_count, history = -1, 0, {}
local finished = false
local function finish(reason)
  if finished then return end
  finished = true
  log("finish: %s after %d frames", reason, frames - entered_at)
  local pc = cpu.state["PC"].value
  log("pc=%08X (%s) sr=%04X sp=%08X vbr=%08X tc=%08X", pc, nearest(pc), cpu.state["SR"].value, cpu.state["SP"].value,
      cpu.state["VBR"].value, cpu.state["TC"].value)
  local r = {}
  for i = 0, 7 do r[#r + 1] = string.format("D%d=%08X", i, cpu.state["D" .. i].value) end
  print(table.concat(r, " "))
  r = {}
  for i = 0, 7 do r[#r + 1] = string.format("A%d=%08X", i, cpu.state["A" .. i].value) end
  print(table.concat(r, " "))
  local hist = {}
  for i = math.max(1, #history - 30), #history do hist[#hist + 1] = string.format("%X(%s)", history[i], nearest(history[i])) end
  log("pc per frame (last %d): %s", #hist, table.concat(hist, " "))
  -- the processes: PCBS's 65 pointers (virtual, so read with translation);
  -- each PCB's flag word (0x54), wait start (0x3C), saved A6 and A7 (the
  -- last two of the twelve registers at 0x08), then the A6 chain's
  -- return addresses
  local pcbs = tonumber(os.getenv("DN_PCBS") or "")
  if pcbs then
    for pid = 0, 64 do
      local pcb = mem:readv_u32(pcbs + 4 * pid)
      if pcb ~= 0 and mem:readv_u32(pcb + 0x08 + 4 * 11) ~= 0 then
        local a6, a7 = mem:readv_u32(pcb + 0x08 + 4 * 10), mem:readv_u32(pcb + 0x08 + 4 * 11)
        local chain = {}
        local fp = a6
        for _ = 1, 10 do
          if fp == 0 or fp % 2 ~= 0 then break end
          local ret = mem:readv_u32(fp + 4)
          chain[#chain + 1] = string.format("%X(%s)", ret, nearest(ret))
          fp = mem:readv_u32(fp)
        end
        log("pcb %d at %08X next=%08X flags=%04X wait_start=%08X a6=%08X a7=%08X ret@a7=%08X: %s", pid, pcb,
            mem:readv_u32(pcb), mem:readv_u16(pcb + 0x54), mem:readv_u32(pcb + 0x3C), a6, a7,
            mem:readv_u32(a7), table.concat(chain, " "))
      end
    end
  end
  -- the frame buffer: 2048-bit lines, physical 0x1000000 (256 KB)
  local fbp = os.getenv("DN_FB_DUMP") or ""
  if fbp ~= "" then
    local f = io.open(fbp, "wb")
    f:write("P4\n2048 1024\n")
    local t = {}
    for a = 0x1000000, 0x103FFFF, 4 do t[#t + 1] = string.pack(">I4", mem:read_u32(a)) end
    f:write(table.concat(t))
    f:close()
    log("frame buffer written to %s", fbp)
  end
  manager.machine:exit()
end

-- the keyboard (apollo_kbd): a key's field by its name's first token,
-- Return by its mask (keyboard1 0x20000000), Space by name; a capital
-- letter or a shifted character with Shift
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
  ["("] = "8", [")"] = "9", ["_"] = "-", ["+"] = "=" }
local function char_keys(ch)
  local shift = nil
  local key = ch
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
  return f, shift and kbd_field(":keyboard4", function(n, fl) return fl.mask == 0x2 end) or nil
end
local key_plan = {}
for item in (os.getenv("DN_KEYS") or ""):gmatch("[^|]+") do
  local at, text = item:match("^(%d+):(.*)$")
  if at then key_plan[#key_plan + 1] = { tonumber(at), text } end
end
local key_queue, key_state, key_wait = {}, "idle", 0
local type_plan = {}
for item in (os.getenv("DN_TYPE") or ""):gmatch("[^|]+") do type_plan[#type_plan + 1] = item end
local waiting_frames = 0
-- the PROM's console input loop, sampled once a frame: its getchar
-- (0xB850..0xB8FA), its caller (0x8BD6..0x8C1C), the cursor (0x18504..
-- 0x1864E) and 0x5EEC..0x5EFA
local function waiting_for_input(pc)
  if (pc >= 0xB800 and pc < 0xB900) or (pc >= 0x8B80 and pc < 0x8C40) or (pc >= 0x18400 and pc < 0x18700)
      or (pc >= 0x5E00 and pc < 0x5F00) then
    return true
  end
  return nearest(pc):match("^NULL_LOOP") ~= nil
end
local function queue_text(text)
  for ch in text:gmatch(".") do
    local f, sh = char_keys(ch)
    if f then key_queue[#key_queue + 1] = { f, sh } else log("no key for %q", ch) end
  end
end
local function key_step()
  if #type_plan > 0 and #key_queue == 0 then
    if waiting_for_input(cpu.state["PC"].value) then waiting_frames = waiting_frames + 1 else waiting_frames = 0 end
    if waiting_frames >= 60 then
      local text = table.remove(type_plan, 1)
      log("typing %q at frame %d", text, frames)
      queue_text(text)
      waiting_frames = 0
    end
  end
  while #key_plan > 0 and frames >= key_plan[1][1] do
    queue_text(table.remove(key_plan, 1)[2])
  end
  if key_wait > 0 then key_wait = key_wait - 1 return end
  if key_state == "down" then
    key_queue[1][1]:clear_value()
    if key_queue[1][2] then key_queue[1][2]:clear_value() end
    table.remove(key_queue, 1)
    key_state, key_wait = "idle", 4
  elseif #key_queue > 0 then
    if key_queue[1][2] then key_queue[1][2]:set_value(1) end
    key_queue[1][1]:set_value(1)
    key_state, key_wait = "down", 4
  end
end

emu.register_frame_done(function()
  frames = frames + 1
  key_step()
  -- the harness's --finish-on: the console showed the text
  if frames % 30 == 0 then
    local f = io.open(out_dir .. "/finish", "r")
    if f then f:close(); os.remove(out_dir .. "/finish"); finish("the console showed the --finish-on text") return end
  end
  if phase == "prom" then
    if frames == 1 then
      for raw in (os.getenv("DN_PROM_WPS") or ""):gmatch("[^|]+") do
        dbg:command("wpset " .. raw)
      end
      if prom_boot then
        set_calendar()
        set_breakpoints()
        phase, entered_at = "run", frames
        return
      end
    end
    -- the second prompt: after the self-test summary is answered with `n'
    if prompt_at < 0 and frames % 30 == 0 and prompt_seen() then
      prompt_at = frames
      log("PROM prompt at frame %d", frames)
    end
    if prompt_at >= 0 and frames == prompt_at + 60 then
      log("PROM parked at pc=%08X sp=%08X vbr=%08X tc=%08X", cpu.state["PC"].value, cpu.state["SP"].value,
          cpu.state["VBR"].value, cpu.state["TC"].value)
      enter()
      phase, entered_at = "run", frames
    end
    if frames > prom_frames then finish("no PROM prompt") end
    return
  end
  local n = frames - entered_at
  if n == trace_after then dbg:command("trace " .. out_dir .. "/trace.txt,maincpu,noloop") end
  if trace_after >= 0 and n == trace_after + trace_frames then dbg:command("trace off") end
  local pc = cpu.state["PC"].value
  history[#history + 1] = pc
  if pc == last_pc then same_count = same_count + 1 else same_count = 0 end
  last_pc = pc
  if same_count >= stuck_frames then finish(string.format("pc stuck at %08X (%s)", pc, nearest(pc))) end
  if n >= run_frames then finish("frame budget exhausted") end
end)
