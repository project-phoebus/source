-- mame_boot_direct.lua - load our RFC image into the DN300's RAM the way
-- sysboot would, and start COLD_START.  Driven by mame_boot_direct.py
-- through environment variables:
--   DOS_IMAGE   the RFC image (dist/sau2/domain_os)
--   DOS_SYMS    "addr name" lines (m68k-elf-nm output) for naming PCs
--   DOS_STOPS   comma list of addresses to log a full register/stack dump at
--   DOS_PROGRESS comma list of addresses to log a one-line PROGRESS at
--   DOS_FLAGS   boot flags word (d2 low; default 8)
--   DOS_FRAMES  frames to run after entry before giving up (default 3000)
--   DOS_TYPE    text to type on the DN300 keyboard (default empty), e.g.
--               "go\r" for the Phase II `)' prompt; typed when the CPU
--               first idles outside the PROM (the PC stays put for
--               DOS_TYPE_IDLE frames, default 60) or, if set, DOS_TYPE_AFTER_FRAMES frames after
--               entry, whichever comes first.  Stages separated by
--               "\31" (ASCII US, from repeated --type) are typed at
--               successive idles, e.g. "y\r" then "go\r"
--   DOS_TYPE_INJECT address of KBD_$RCV: type every character by injection
--               instead (see below); needed for any text beyond a few
--               lower-case letters, digits 0/3/5/6/9 and Return
--   DOS_STUCK_FRAMES frames the PC must stay put (outside typing) before the
--               run ends (default 120)
--   DOS_DUMP    "phys:len,..." physical ranges logged as words at the end
--   DOS_PHYS_WPS "addr,len[,r|w|rw]|..." physical watchpoints: a tap on the
--               physical space logs "PWP" lines to error.log (the debugger's
--               wpset takes only a CPU's spaces, and the CPU's program space
--               is virtual)
--   DOS_CONSOLE address of the PROM's console output routine (0x818): its
--               characters are collected for --expect / DOS_FINISH_ON
--   DOS_FINISH_ON end the run once every stage is typed and the console has
--               printed this text
--   DOS_FRAME_LOG if set, log "FRAME n t=SECONDS pc=PC sr=SR" (frames since
--               entry, emulated time, where the CPU is at the frame's end)
--               to error.log every frame, so breakpoint lines between them
--               can be placed in time and the PCs serve as a 1-per-frame
--               sampling profile
--   DOS_PERIODIC_CMD a debugger command (e.g. a logerror reading kernel
--               cells as d@VA) run every DOS_PERIODIC_FRAMES frames (default
--               600) after entry and once more at the end of the run
--   (a DOS_TYPE stage may carry "\3FRAMES\3" and "PROMPT\2" prefixes, from
--   --wait and --expect; see split_stage)
-- Needs -debug -debugger none (for bpset actions) and -video none.

local PAGE, LOAD, ENTRY, BOOT_SP = 0x400, 0x101400, 0x101424, 0x17CFE0
local cpu = manager.machine.devices[":maincpu"]
-- Physical memory (the image pages, the PTT/PFT/MMU registers, DOS_DUMP).
-- The DN300 driver's MMU device owns the physical bus as its "physical"
-- space and the CPU's program space is the virtual view; with the older
-- external-MMU-hook build (M68010EMMU) the CPU's program space is physical.
local mmu = manager.machine.devices[":apollo_dn300_mmu"]
local mem = mmu and mmu.spaces["physical"]
local mem_name = "apollo_dn300_mmu physical"
if not mem then mem, mem_name = cpu.spaces["program"], "maincpu program (hook build)" end
local dbg = manager.machine.debugger

local function log(fmt, ...) print(string.format("BOOT " .. fmt, ...)) end

local syms = {}
for line in io.lines(os.getenv("DOS_SYMS")) do
  local a, n = line:match("^(%x+)%s+%S%s+(%S+)$")
  if a then syms[#syms + 1] = { tonumber(a, 16), n } end
end
table.sort(syms, function(x, y) return x[1] < y[1] end)
local function nearest(pc)
  local best
  for _, s in ipairs(syms) do
    if s[1] <= pc then best = s else break end
  end
  if not best or pc - best[1] > 0x10000 then return "?" end
  return string.format("%s+0x%X", best[2], pc - best[1])
end

local function split(s)
  local t = {}
  for v in (s or ""):gmatch("[^,]+") do t[#t + 1] = tonumber(v) end
  return t
end

local image = assert(io.open(os.getenv("DOS_IMAGE"), "rb")):read("a")
local info_split = string.unpack(">I4", image, 0x1C + 1)
local info_move = string.unpack(">I4", image, 0x20 + 1)
local flags = tonumber(os.getenv("DOS_FLAGS") or "8")
local run_frames = tonumber(os.getenv("DOS_FRAMES") or "3000")
local frame_log = (os.getenv("DOS_FRAME_LOG") or "") ~= ""
local periodic_cmd = os.getenv("DOS_PERIODIC_CMD") or ""
local periodic_frames = tonumber(os.getenv("DOS_PERIODIC_FRAMES") or "600")

local phase, frames, entered_at = "prom", 0, 0

-- Keyboard input.  The dn300 keyboard device (mame apollo_dn300_kbd.cpp)
-- declares PORT_NAME/PORT_CODE but no PORT_CHAR, so the natural keyboard
-- cannot type; instead each character presses its ioport field for
-- KEY_HOLD frames and releases it for KEY_GAP frames (the device scans its
-- ports every 5 ms).  A field is found by its PORT_NAME's first token
-- ("G", "1 !" -> '1'); Return has no PORT_NAME, so it is the keyboard1
-- field with mask 0x20000000 (PORT_CODE(KEYCODE_ENTER)).  port.fields is a
-- table keyed by name, and keyboard1's three unnamed fields (Backspace,
-- Tab, Return) share the generic type name, so only the last one declared
-- survives; Return is declared last, which is why it can be found.
local type_stages = {}
for stage in (os.getenv("DOS_TYPE") or ""):gmatch("[^\31]+") do type_stages[#type_stages + 1] = stage end
-- A stage "PROMPT\2TEXT" (from --expect) waits, besides the idle, until
-- the console has printed PROMPT since the previous stage was typed.  The
-- console is the PROM's output routine (DOS_CONSOLE, 0x818): a breakpoint
-- there prints each character (d1) to the debugger console log as "CONxx".
-- A stage may also start with "\3FRAMES\3" (from --wait): it is typed no
-- earlier than FRAMES frames after the previous stage was typed.
local type_expect, type_not_before = "", 0
local function split_stage(st)
  local w, rest = st:match("^\3(%d+)\3(.*)$")
  st = rest or st
  local e, t = st:match("^(.-)\2(.*)$")
  if e then return t, e, tonumber(w or "0") end
  return st, "", tonumber(w or "0")
end
local type_text, type_wait_frames
type_text, type_expect, type_wait_frames = split_stage(table.remove(type_stages, 1) or "")
local con_text, con_seen, con_finish_seen = "", 0, false
local function con_poll()
  if not dbg then return end
  local cl = manager.machine.debugger.consolelog
  local n = #cl
  -- each printf ends its line, so cl[n] is the empty line being written
  -- (indices past it read as "" too)
  local chunk = {}
  for i = math.max(con_seen + 1, n - 2000), n - 1 do
    local line = cl[i] or ""
    for hex in line:gmatch("CON(%x%x)") do chunk[#chunk + 1] = string.char(tonumber(hex, 16) & 0x7F) end
    con_seen = i
  end
  if #chunk > 0 then
    con_text = con_text .. table.concat(chunk)
    -- note DOS_FINISH_ON before trimming: the PROM can print hundreds of
    -- characters in the frame after it
    local fin = os.getenv("DOS_FINISH_ON")
    if fin and fin ~= "" and con_text:find(fin, 1, true) then con_finish_seen = true end
    con_text = con_text:sub(-400)
  end
end
local type_idle = tonumber(os.getenv("DOS_TYPE_IDLE") or "60")
local type_after = tonumber(os.getenv("DOS_TYPE_AFTER_FRAMES") or "-1")
local type_queue, type_state, type_wait = nil, "idle", 0
-- DOS_KEY_HOLD / DOS_KEY_GAP override the timing (frames); a busy DM pad
-- drops characters typed at the default rate.
local KEY_HOLD = tonumber(os.getenv("DOS_KEY_HOLD") or "") or 4
local KEY_GAP = tonumber(os.getenv("DOS_KEY_GAP") or "") or 4
local function key_field(ch)
  local want = ch:upper()
  for tag, port in pairs(manager.machine.ioport.ports) do
    if tag:find("keyboard") then
      for name, field in pairs(port.fields) do
        if ch == "\r" then
          if tag:match("keyboard1$") and field.mask == 0x20000000 then return field end
        elseif ch == " " then
          if name:lower():find("space") then return field end
        elseif name:match("^(%S+)") == want then
          return field
        end
      end
    end
  end
  return nil
end
-- Characters by scan index (keyboardN field = index // 32 + 1, mask
-- 1 << index % 32) and shift, from the device's s_code_table: the table
-- row a field's index selects, not its PORT_NAME, decides the character.
-- This follows the patched table of the dn300 keyboard in our MAME, where
-- every code is what SR10.2's SMD_$KTT (0xE273FE) translates to the key's
-- legend: row 27 unshifted 0x7B -> '[' / shifted 0x5B -> '{', row 28
-- ']' / '}', row 41 (the host \ | key) 0xC8 '\' / 0xC9 '|', row 51
-- 0xCC '/' / 0xDC '?', row 29 Return 0xCB (the DM's CR), row 15
-- Backspace 0xDE.  Characters not listed fall back to key_field
-- (PORT_NAME's first token, unshifted).
local SCAN = { ["`"] = 0, ["\r"] = 29, ["\b"] = 15, [" "] = 53, ["-"] = 12, ["="] = 13,
  ["["] = 27, ["]"] = 28, [";"] = 39, ["'"] = 40, ["\\"] = 41, [","] = 49, ["."] = 50, ["/"] = 51 }
local SHIFTED = { ["~"] = 0, ["!"] = 2, ["@"] = 3, ["#"] = 4, ["$"] = 5, ["%"] = 6, ["^"] = 7, ["&"] = 8,
  ["*"] = 9, ["("] = 10, [")"] = 11, ["_"] = 12, ["+"] = 13, ["{"] = 27, ["}"] = 28, [":"] = 39,
  ['"'] = 40, ["|"] = 41, ["<"] = 49, [">"] = 50, ["?"] = 51 }
for i, c in ipairs({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }) do SCAN[c] = i + 1 end
for i, c in ipairs({ "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" }) do SCAN[c] = 16 + i end
for i, c in ipairs({ "a", "s", "d", "f", "g", "h", "j", "k", "l" }) do SCAN[c] = 29 + i end
for i, c in ipairs({ "z", "x", "c", "v", "b", "n", "m" }) do SCAN[c] = 41 + i end
local function field_by_mask(tag, mask)
  for t, port in pairs(manager.machine.ioport.ports) do
    if t:match(tag .. "$") then
      for _, field in pairs(port.fields) do
        if field.mask == mask then return field end
      end
    end
  end
  return nil
end
local function scan_field(x) return field_by_mask(":keyboard" .. (x // 32 + 1), 1 << (x % 32)) end
-- returns the key's field and, for a shifted character, the Shift field
local function char_keys(ch)
  -- control characters ^A..^Z: the letter's key with Ctrl (keyboard4 mask 0x4);
  -- the device's Control column sends 0x01..0x1A
  local b = ch:byte()
  if b >= 1 and b <= 26 and ch ~= "\r" and ch ~= "\b" then
    local f = scan_field(SCAN[string.char(b + 96)])
    if f then return f, field_by_mask(":keyboard4", 0x4) end
  end
  local x, shift = SCAN[ch], false
  if not x and ch:match("%u") then x, shift = SCAN[ch:lower()], true end
  if not x and SHIFTED[ch] then x, shift = SHIFTED[ch], true end
  if x then
    local f = scan_field(x)
    -- the two Shift fields share a name, so only the right one (0x20) survives in port.fields
    if f then return f, shift and (field_by_mask(":keyboard4", 0x2) or field_by_mask(":keyboard4", 0x20)) or nil end
  end
  return key_field(ch), nil
end
-- Injection (DOS_TYPE_INJECT) is a fallback for an unpatched MAME, whose
-- dn300 keyboard sends 7 data bits
-- with even parity and the kernel reads the line as 8 bits, so a byte of odd
-- weight arrives with bit 7 set (' ' as 0xA0, 'n' as 0xEE) and goes through
-- the SMD_$KTT key translation table as a function key: only some characters
-- can be typed at all (no space, no 'h', 'k', 'm', 'n', 'y', 'z'), and the
-- device ignores Shift in some rows.  With injection each character presses
-- one key and a breakpoint at KBD_$RCV's entry replaces the received byte
-- (the high byte of the word at SP+8) with the byte the US SMD_$KTT
-- (0xE273FE) translates to the character: the character itself except
-- '/' 0xCC, '?' 0xDC, '\' 0xC8, '|' 0xC9, '[' 0x7B, ']' 0x7D, '{' 0x5B,
-- '}' 0x5D, Return 0xCB (the keyboard's own codes for those keys).  The breakpoint fires
-- once per armed key (temp1), so stray bytes pass through unchanged.
local inject_rcv = tonumber(os.getenv("DOS_TYPE_INJECT") or "")
local KTT_PRE = { ["/"] = 0xCC, ["?"] = 0xDC, ["\\"] = 0xC8, ["|"] = 0xC9,
  ["["] = 0x7B, ["]"] = 0x7D, ["{"] = 0x5B, ["}"] = 0x5D,
  ["\r"] = 0xCB }   -- the RETURN key (KTT -> 0x96, the DM's CR; plain 0x0D is no Return to the DM)
local function start_typing(why)
  if type_queue or type_text == "" then return end
  log("typing %q (%s) at frame %d", type_text, why, frames - entered_at)
  type_queue = {}
  for ch in type_text:gmatch(".") do
    local f, sh = char_keys(ch)
    local byte = nil
    if inject_rcv then f, sh, byte = scan_field(SCAN["c"]), nil, KTT_PRE[ch] or ch:byte() end
    if f then type_queue[#type_queue + 1] = { f, sh, byte } else log("no key field for %q", ch) end
    if f and os.getenv("DOS_TYPE_DEBUG") then
      log("key %q -> %s %s mask %08X%s", ch, f.port.tag, f.name, f.mask, sh and " +shift" or "")
    end
  end
end
local function type_step()
  if not type_queue or type_state == "done" then return end
  if type_wait > 0 then type_wait = type_wait - 1 return end
  if type_state == "down" then
    type_queue[1][1]:clear_value()
    if type_queue[1][2] then type_queue[1][2]:clear_value() end
    table.remove(type_queue, 1)
    type_state, type_wait = "up", KEY_GAP
  elseif #type_queue == 0 then
    type_state = "done"
    log("typing done at frame %d", frames - entered_at)
    if #type_stages > 0 then
      -- next stage: typed at the next idle
      type_text, type_expect, type_wait_frames = split_stage(table.remove(type_stages, 1))
      type_not_before = frames + type_wait_frames
      type_queue, type_state, type_after = nil, "idle", -1
    end
  else
    if type_queue[1][3] then dbg:command(string.format("do temp0=0x%X", type_queue[1][3])); dbg:command("do temp1=1") end
    if type_queue[1][2] then type_queue[1][2]:set_value(1) end
    type_queue[1][1]:set_value(1)
    -- the next stage's prompt is looked for in what the console prints
    -- from this stage's last key on
    if #type_queue == 1 then con_text, con_finish_seen = "", false end
    type_state, type_wait = "down", KEY_HOLD
  end
end
local last_pc, same_count, history, rom_count = -1, 0, {}, 0

local function load_image()
  local pages = 0
  for i = 0, #image - 1, PAGE do
    local ppn = (LOAD + i) >> 10
    if ppn >= info_split then ppn = ppn - info_split + info_move end
    local phys = ppn << 10
    local chunk = image:sub(i + 1, i + PAGE)
    for j = 1, #chunk - 1, 2 do
      mem:write_u16(phys + j - 1, string.unpack(">I2", chunk, j))
    end
    if #chunk % 2 == 1 then mem:write_u8(phys + #chunk - 1, chunk:byte(#chunk)) end
    pages = pages + 1
  end
  -- verify two pages
  for _, off in ipairs({ 0, (#image - 1) // PAGE * PAGE }) do
    local ppn = (LOAD + off) >> 10
    if ppn >= info_split then ppn = ppn - info_split + info_move end
    for j = 0, 15 do
      local want = image:byte(off + j + 1)
      local got = mem:read_u8((ppn << 10) + j)
      if want ~= got then log("readback mismatch at file 0x%X: %02X vs %02X", off + j, want, got) end
    end
  end
  log("loaded %d pages (split PPN 0x%X -> 0x%X) through the %s space", pages, info_split, info_move, mem_name)
end

local function regdump_action(name)
  local regs = "pc=%08X sr=%04X sp=%08X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X"
  local args = "pc,sr,sp,d0,d1,d2,d3,d4,d5,d6,d7,a0,a1,a2,a3,a4,a5,a6"
  local stk, sargs = "", ""
  for i = 0, 15 do
    stk = stk .. " %08X"
    sargs = sargs .. string.format(",d@(sp+%d)", i * 4)
  end
  return string.format('{logerror "STOP %s %s stack:%s\\n",%s%s;go}', name, regs, stk, args, sargs)
end

local function exc_action(a)
  -- the raw exception frame (29 words: a 68010 bus/address error frame is
  -- sr, pc, format/vector, then the fault information) and the registers
  local regs = "d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X"
  local args = "d0,d1,d2,d3,d4,d5,d6,d7,a0,a1,a2,a3,a4,a5,a6"
  local stk, sargs = "", ""
  for i = 0, 28 do
    stk = stk .. " %04X"
    sargs = sargs .. string.format(",w@(sp+%d)", i * 2)
  end
  -- the console output routine also prints its character for con_poll
  -- (a second breakpoint at the same address would never be reached)
  local con = (a == tonumber(os.getenv("DOS_CONSOLE") or "")) and 'printf "CON%02X\\n",d1;' or ""
  return string.format('{logerror "EXC handler=%%08X sp=%%08X %s frame:%s\\n",pc,sp,%s%s;%sgo}', regs, stk, args, sargs, con)
end

local phys_taps = {}   -- keeps the tap handles alive
local function install_phys_wp(spec)
  local a, n, mode = spec:match("^%s*([^,]+),([^,]+),?(%a*)%s*$")
  a, n, mode = tonumber(a), tonumber(n), (mode ~= "" and mode or "w")
  if not a or not n or n < 1 then log("bad physical watchpoint %q", spec) return end
  local function tap(kind)
    return function(offset, data, mask)
      manager.machine:logerror(string.format("PWP %s pc=%08X a=%06X d=%04X m=%04X",
        kind, cpu.state["CURPC"].value, offset, data, mask))
    end
  end
  if mode:find("r") then phys_taps[#phys_taps + 1] = mem:install_read_tap(a, a + n - 1, "pwp_r" .. #phys_taps, tap("r")) end
  if mode:find("w") then phys_taps[#phys_taps + 1] = mem:install_write_tap(a, a + n - 1, "pwp_w" .. #phys_taps, tap("w")) end
  log("physical watchpoint %06X..%06X %s on the %s space", a, a + n - 1, mode, mem_name)
end

local function set_breakpoints()
  for _, a in ipairs(split(os.getenv("DOS_PROM_HANDLERS"))) do
    dbg:command(string.format("bpset 0x%X,1,%s", a, exc_action(a)))
  end
  for _, a in ipairs(split(os.getenv("DOS_STOPS"))) do
    local cmd = string.format("bpset 0x%X,1,%s", a, regdump_action(nearest(a)))
    log("bp stop %08X %s (%d chars)", a, nearest(a), #cmd)
    dbg:command(cmd)
  end
  for raw in (os.getenv("DOS_RAW_BPS") or ""):gmatch("[^|]+") do
    dbg:command("bpset " .. raw)
  end
  for raw in (os.getenv("DOS_RAW_WPS") or ""):gmatch("[^|]+") do
    dbg:command("wpset " .. raw)
  end
  if inject_rcv then
    dbg:command("do temp1=0")
    dbg:command(string.format("bpset 0x%X,temp1,{do b@(sp+8)=temp0;do temp1=0;go}", inject_rcv))
  end
  for _, a in ipairs(split(os.getenv("DOS_PROGRESS"))) do
    dbg:command(string.format('bpset 0x%X,1,{logerror "PROGRESS %s pc=%%08X sp=%%08X\\n",pc,sp;go}', a, nearest(a)))
  end
end


-- The PROM's "enter mapped mode" routine (DN300 boot PROM MD REV 5, ROM
-- 0x10BA..0x1130, called from its boot paths): copy the ROM vectors to the
-- RAM trap page 0x100400, clear the PTT, fill the PFT with self-linked
-- end-of-chain entries, walk the PROM's map table at ROM 0x11E0 with the
-- same insert algorithm COLD's cold_map_pages uses, and enable the MMU.
-- sysboot leaves these tables in place and re-enables the MMU before it
-- jumps to COLD (sysboot 0x17F668), so COLD's first MMU access (the word
-- at VA 0xFFB400, COLD 0x10154A) resolves to the register at 0x8000.
local PROM_MAP = {                     -- count, first PPN, first VA (ROM 0x11E0)
  { 0x0F, 0x001, 0x000400 },           -- PROM 0x400..0x3FFF one-to-one
  { 0x10, 0x010, 0xFFB800 },           -- PFT
  { 0x01, 0x020, 0xFFB400 },           -- MMU
  { 0x01, 0x021, 0xFFB000 },           -- SIO
  { 0x01, 0x022, 0xFFAC00 },           -- timers
  { 0x01, 0x027, 0xFFA800 },           -- disk / floppy / calendar
  { 0x01, 0x026, 0xFF9C00 },           -- ring
  { 0x01, 0x025, 0xFF9800 },           -- display 1
  { 0x01, 0x024, 0xFFA000 },           -- DMA
  { 0x80, 0x080, 0xFC0000 },           -- display memory
  { 0x02, 0x02C, 0xFF7000 },           -- FPU ctl / cmd
  { 0x03, 0x02E, 0xFF7800 },           -- FPU cs ..
  { 0x01, 0x400, 0xE00000 },           -- MD stack / data (phys 0x100000)
  { 0x01, 0x401, 0x000000 },           -- trap page (phys 0x100400)
  { 0x200, 0x200, 0x080000 },          -- phys 0x80000..0xFFFFF one-to-one
  { 0xBFE, 0x402, 0x100800 },          -- phys 0x100800..0x3FFFFF one-to-one
}
local PFT, PTT = 0x4000, 0x700000

local function prom_enter_mapped()
  for i = 0, 0x3FC, 4 do mem:write_u32(0x100400 + i, mem:read_u32(i)) end   -- 0x10BA..0x10CA
  mem:write_u8(0x100400, 0xFF)                                              -- 0x10CE
  mem:write_u16(0x8000, 2)                                                  -- 0x10D6 PTT access
  mem:write_u8(0x8005, 0x40)                                                -- 0x10DE
  for i = 0, 1023 do mem:write_u16(PTT + i * 0x400, 0) end                  -- 0x10E6..0x10FA
  for i = 0, 4095 do mem:write_u32(PFT + i * 4, 0xFE008000 | i) end         -- 0x10FC..0x110E
  for _, e in ipairs(PROM_MAP) do                                           -- 0x117A..0x11DE
    local count, ppn, va = e[1], e[2], e[3]
    for k = 0, count - 1 do
      local d3 = ((va >> 4) & 0xF0000) ~ 0x701000
      local slot = PTT + (va & 0xFFFFF)
      local head = mem:read_u16(slot) & 0xFFF
      if head == 0 then
        d3 = (d3 | 0x8000) + ppn                 -- end of chain, linked to itself
        mem:write_u16(slot, ppn)
      else
        local hent = mem:read_u32(PFT + head * 4)
        local d5 = hent & 0xFFF
        d3 = d3 ~ d5                             -- new entry links to the head's old link
        d5 = d5 ~ ppn
        mem:write_u32(PFT + head * 4, hent ~ d5) -- head links to the new entry
      end
      mem:write_u32(PFT + ppn * 4, d3)
      ppn = ppn + 1
      va = va + 0x400
    end
  end
  mem:write_u8(0x8005, 0x80)                                                -- 0x111A
  mem:write_u16(0x8000, 1)                                                  -- 0x1122 MMU on
  mem:write_u8(0x8005, 0)                                                   -- 0x112A (VA 0xFFB405)
  log("PROM map installed: pid/priv=%04X PTT[5]=%04X PFT[0x405]=%08X PFT[0x20]=%08X",
      mem:read_u16(0x8000), mem:read_u16(PTT + 5 * 0x400), mem:read_u32(PFT + 0x405 * 4), mem:read_u32(PFT + 0x20 * 4))
end

local function enter()
  load_image()
  prom_enter_mapped()
  -- the frame COLD_START pops:
  -- return address, d1 = device/ctlr, d2 = unit/flags, a1, three spare longs
  local frame = string.pack(">I4I4I4I4I4I4I4", 0x17F6A8, 0, flags & 0xFFFF, 0, 0, 0, 0)
  for j = 1, #frame, 4 do mem:write_u32(BOOT_SP + j - 1, string.unpack(">I4", frame, j)) end
  if dbg then set_breakpoints() else log("no debugger: run with -debug -debugger none for breakpoints") end
  for raw in (os.getenv("DOS_PHYS_WPS") or ""):gmatch("[^|]+") do
    install_phys_wp(raw)
  end
  cpu.state["SR"].value = 0x2700
  cpu.state["SP"].value = BOOT_SP
  cpu.state["PC"].value = ENTRY
  log("entry pc=%08X sp=%08X sr=%04X", cpu.state["PC"].value, cpu.state["SP"].value, cpu.state["SR"].value)
end

local finished = false
local function finish(reason)
  if finished then return end   -- several end conditions can hold in one frame
  finished = true
  log("finish: %s after %d frames", reason, frames - entered_at)
  if periodic_cmd ~= "" and dbg then dbg:command(periodic_cmd) end
  if os.getenv("DOS_CONSOLE") and dbg then
    local cl = manager.machine.debugger.consolelog
    log("console log %d lines, last %q; console tail %s; expect %q text %q", #cl, tostring(cl[#cl]), con_text:sub(-60):gsub("[^%w%p ]", "."), type_expect, type_text)
  end
  local pc = cpu.state["PC"].value
  log("pc=%08X (%s) sr=%04X sp=%08X usp=%08X", pc, nearest(pc), cpu.state["SR"].value, cpu.state["SP"].value, cpu.state["USP"].value)
  for i = 0, 7 do io.write(string.format("D%d=%08X ", i, cpu.state["D" .. i].value)) end
  print()
  for i = 0, 7 do io.write(string.format("A%d=%08X ", i, cpu.state["A" .. i].value)) end
  print()
  local hist = {}
  for i = math.max(1, #history - 40), #history do hist[#hist + 1] = string.format("%X", history[i]) end
  log("pc per frame (last %d): %s", #hist, table.concat(hist, " "))
  -- DOS_DUMP: "phys:len,..." physical ranges to print as words at the end
  for spec in (os.getenv("DOS_DUMP") or ""):gmatch("[^,]+") do
    local a, n = spec:match("^(%x+):(%x+)$")
    if a then
      a, n = tonumber(a, 16), tonumber(n, 16)
      local words = {}
      for i = 0, n - 2, 2 do words[#words + 1] = string.format("%04X", mem:read_u16(a + i)) end
      log("dump %08X: %s", a, table.concat(words, " "))
    end
  end
  manager.machine:exit()
end

emu.register_frame_done(function()
  frames = frames + 1
  if phase == "prom" then
    if frames == 30 then
      log("PROM parked at pc=%08X sp=%08X", cpu.state["PC"].value, cpu.state["SP"].value)
      enter()
      phase = "run"
      entered_at = frames
    end
    return
  end
  if periodic_cmd ~= "" and dbg and (frames - entered_at) % periodic_frames == 0 then
    dbg:command(periodic_cmd)
  end
  if frame_log then
    manager.machine:logerror(string.format("FRAME %d t=%.4f pc=%08X sr=%04X\n", frames - entered_at,
      manager.machine.time:as_double(), cpu.state["PC"].value, cpu.state["SR"].value))
  end
  local pc = cpu.state["PC"].value
  history[#history + 1] = pc
  if pc == last_pc then same_count = same_count + 1 else same_count = 0 end
  last_pc = pc
  if pc < 0x4000 then rom_count = rom_count + 1 else rom_count = 0 end
  if rom_count >= (tonumber(os.getenv("DOS_ROM_FRAMES") or "30")) then finish(string.format("fell into the PROM (pc=%08X)", pc)) end
  if type_after >= 0 and frames - entered_at >= type_after then start_typing("after frames") end
  -- idling in the PROM (pc < 0x4000: its display output waits) does not count
  if os.getenv("DOS_CONSOLE") then con_poll() end
  if same_count >= type_idle and pc >= 0x4000 and type_text ~= "" and not type_queue
     and (type_expect == "" or con_text:find(type_expect, 1, true)) and frames >= type_not_before then
    start_typing(string.format("idle at %08X %s", pc, nearest(pc)))
    same_count = 0
  end
  type_step()
  if type_queue and type_state ~= "done" then same_count = 0 end
  -- DOS_FINISH_ON: end the run once every stage is typed and the console
  -- has printed this text since the last one
  local fin = os.getenv("DOS_FINISH_ON")
  local all_typed = type_text == "" or (type_state == "done" and #type_stages == 0)
  if fin and fin ~= "" and all_typed and con_finish_seen then
    finish(string.format("console printed %q", fin))
  end
  local waiting = type_text ~= "" and not type_queue and frames < type_not_before
  if same_count >= tonumber(os.getenv("DOS_STUCK_FRAMES") or "120") and not waiting then finish(string.format("pc stuck at %08X (%s)", pc, nearest(pc))) end
  if frames - entered_at >= run_frames then finish("frame budget exhausted") end
end)
