{ os/os.ins.pas - OS_ (the kernel's start-up and shutdown), for the
  Domain Pascal tree.

  What the Pascal files use.  Include base/base.ins.pas and
  misc/crash_system.ins.pas before it.
}

{ OS_$BOOT_ERRCHK (os/boot_errchk.pas): line is arg_str's length; the
  result is true when the status is no error. }
function os_$boot_errchk(in format_str: univ crash_$chars_t;
                         in arg_str: univ crash_$chars_t;
                         in line: integer; status: status_$t): boolean;
  extern;

type
  { The bytes OS_$DATA_COPY moves, the formal type of its `univ'
    parameters.  The actuals are variables passed by address, which
    `univ' takes whatever their size (ref 5.3.3). }
  os_$data_t = array[1..1024] of char;

{ OS_$DATA_COPY (hand assembly, in the map's NETWORK_ASM code segment;
  network/m68k/data_copy.s): it reads its arguments off the stack, the
  first the source, read; the second the destination, written; the
  third the length, a longword by value, then copies longwords.
  APP_$RECEIVE pushes the length's value and the two addresses.  The
  length by value needs `val_param'; src `in', dst `out', `univ'. }
procedure os_$data_copy(in src: univ os_$data_t; out dst: univ os_$data_t;
                        len: integer32);
  options(extern, val_param);

{ }

type
  { The kernel's revision record OS_$REV, 0xCC bytes.  GET_BUILD_TIME
    reads it through A5: os_rev tested; major .. build passed by address
    as words to `%wd' and patch and build tested; the three lengths
    passed to `%a' as a length's address, longwords (VFMT reads a
    non-positive first word as a longword's high half, vfmt/main.pas),
    and the three 32-character texts by address.  OS_$GET_REV_INFO
    copies all 0xCC bytes.  The image's values: 0, 10, 2, 0, 0, the
    longword 16#46347587 at +0x0C (the same as BUILD_$TIME's), zeros to
    +0x60, 16#10, 0, 16#1D, 'Domain/OS kernel', 32 blanks, 'October 13,
    1989  11:47:27 am'.  The +0x0C longword is read by no compiled code
    (stamp). }
  os_$rev_t = record
    os_rev: integer32;                    { 0x00 }
    major: integer;                       { 0x04 }
    minor: integer;                       { 0x06 }
    patch: integer;                       { 0x08 }
    build: integer;                       { 0x0A }
    stamp: integer32;                     { 0x0C }
    reserved_10: array[1..80] of char;    { 0x10 }
    name_len: integer32;                  { 0x60 }
    date_len: integer32;                  { 0x64 }
    time_len: integer32;                  { 0x68 }
    name: array[1..32] of char;           { 0x6C }
    date: array[1..32] of char;           { 0x8C }
    time: array[1..32] of char;           { 0xAC }
  end;

var
  { OS_$REV and BUILD_$TIME (map symbols, the two objects of the map's
    PRINT_BUILD_TIME data segment, .DATA): the PRINT_BUILD_TIME module's
    data (defined in its module; misc/README.md).  BUILD_$TIME is
    the longword 16#46347587, which no compiled code addresses; OS_$INIT
    names OS_$REV by its address. }
  os_$rev: extern os_$rev_t;
  build_$time: extern integer32;

{ }

{ OS_$DATA_ZERO: zeroes len bytes.  Hand assembly, not compiled code:
  it lies in the map's NETWORK_ASM code segment with OS_$DATA_COPY, and
  stores zeros with move-immediate forms and a non-relocated zero
  address, forms compiled code does not use; network/m68k/data_zero.s.
  The destination's slot is used as the address, and the length read
  from its slot by value: `val_param', the destination by address
  (`out', univ, as OS_$DATA_COPY's).  XPD_$INIT pushes the length and
  XPD_$DATA's address. }
procedure os_$data_zero(out dst: univ os_$data_t; len: integer32);
  options(extern, val_param);

{ }

{ OS_DISK_PROC - forget a volume's entries in VTOC_'s UID cache. }
procedure os_disk_proc(proc_id: integer); options(extern, val_param);

{ }

var
  { The OS_DISK markers (map symbols): OS_DISK_PROC_END (inside the 4
    zero bytes of the map's OS_DISK_END code segment, no code),
    OS_DISK_DATA (VTOC_'s block's address, a link mark) and
    OS_DISK_DATA_END; OS_DISK_PROC (the routine above) opens the code
    run.  disk_$diskless_init passes their addresses to MST_$WIRE_AREA
    as constant cells.  Labels the build places, no objects of a module,
    as NETLOG's (netlog/netlog.ins.pas): extern chars, of which only the
    address is used. }
  os_disk_proc_end: extern char;
  os_disk_data: extern char;
  os_disk_data_end: extern char;

{ }

type
  { The boot device record, 8 bytes: OS_$INIT stores its words. }
  os_$boot_device_t = record
    device: integer;                      { 0x00 }
    reserved: integer;                    { 0x02 }
    ctlr: integer;                        { 0x04 }
    unit: integer;                        { 0x06 }
  end;

  { The shutdown eventcount's 12 bytes, a level-1 eventcount's layout
    (ec/ec.ins.pas ec_$eventcount_t: the value and the waiter list's two
    links), declared here so that this file's users need no ec insert. }
  os_$shutdown_ec_t = record
    value: integer32;                     { 0x00 }
    waiter_list_head: univ_ptr;           { 0x04 }
    waiter_list_tail: univ_ptr;           { 0x08 }
  end;

var
  { OS_$BOOT_DEVICE and OS_$SHUTTING_DOWN_FLAG (map symbols, the first
    objects of the OS .DATA block, `define'd in os/os.pas): OS_$SHUTDOWN
    sets the flag. }
  os_$boot_device: extern os_$boot_device_t;
  os_$shutting_down_flag: extern boolean;

  { OS_$SHUTDOWN_EC (map symbol, the one object of the map's
    OS_WIRED_START data segment in WIRED_DATA, `define'd in
    os/os_wired_start.pas): the shutdown eventcount, value 0, its waiter
    list linked to itself.  OS_$GET_EC registers it. }
  os_$shutdown_ec: extern os_$shutdown_ec_t;

  { The shut-down-wired run's markers (map symbols):
    OS_PROC_SHUTWIRED_END (inside the 4 bytes of the map's
    OS_SHUTWIRED_END code segment, no code), OS_DATA_SHUTWIRED (the label
    of FILE_'s .DATA block) and OS_DATA_SHUTWIRED_END (DTTY_ASM's start).
    OS_$SHUTDOWN passes their addresses to MST_$WIRE_AREA as constant
    cells; the run's start is the routine OS_PROC_SHUTWIRED (below).
    Labels the build places, as os_disk_proc_end's: extern chars, of
    which only the address is used. }
  os_proc_shutwired_end: extern char;

  { The boot-only run's markers (map symbols): OS_INIT_START (the
    OS_INIT_PROC section's start, also AST_$INIT's address) and
    OS_INIT_END (OS_INIT_DATA's end).  os_$start_proc2 forms their
    addresses as constants, the end's plus 16#7FFF folded in (relocated
    cells).  Labels, as the others: extern chars. }
  os_init_start: extern char;
  os_init_end: extern char;
  os_data_shutwired: extern char;
  os_data_shutwired_end: extern char;

{ OS_PROC_SHUTWIRED (os/proc_shutwired.pas, a fragment for FILE_'s
  module): its address is the shut-down-wired run's start. }
procedure os_proc_shutwired(in out status: status_$t); extern;

{ VTOP_OR_CRASH (os/vtop_or_crash.pas): the result is the physical
  page. }
function vtop_or_crash(va: integer32): integer32; extern;

{ OS_$INSTALL_DISPLAY_ASTE - make the display memory a canned object. }
procedure os_$install_display_aste(in uid: uid_$t; va: integer32;
                                   in size: integer32;
                                   in touch: boolean);
  extern;

{ DUMMY_INTERRUPT_HANDLER - an interrupt routine that claims every
  interrupt. }
function dummy_interrupt_handler: boolean; extern;

{ OS_$SHUTDOWN (os/shutdown.pas): status is read only with
  `crash_reboot'. }
procedure os_$shutdown(status: status_$t); extern;

{ OS_$CHKSUM (os/chksum.pas): the first three parameters are not read;
  `in univ', since OS_$INIT passes literals and their types are not
  seen. }
procedure os_$chksum(in param_1: univ integer32;
                     in param_2: univ integer32;
                     in param_3: univ integer32;
                     out enable: boolean; out status_ret: status_$t);
  extern;

{ OS_$GET_EC - get the shutdown eventcount as an EC2 handle. }
procedure os_$get_ec(in param_1: univ integer32; out ec_ret: univ_ptr;
                     out status: status_$t);
  extern;

type
  { The 0x90-byte VTOCE OS_$INSTALL_DISPLAY_ASTE (and OS_$INIT) build by
    hand for a canned object: the new format's first 0x90 bytes, as
    vtoc/vtoc.ins.pas vtoce_$t, seen with the fields OS stores (file_uid
    +0x04, length +0x14, acl_uid +0x88), and as 36 longwords, cleared by
    a `for' loop.  Declared here, not as vtoce_$t, so that this file
    needs no VTOC_ insert.  Probed with dpc: file_uid 0x04, length 0x14,
    field_74 0x74, acl_uid 0x88, size 0x90. }
  os_$init_vtoce_t = record
    case integer of
      1: (reserved_00: integer32;         { 0x00 }
          file_uid: uid_$t;               { 0x04 }
          reserved_0c: integer32;         { 0x0C }
          reserved_10: integer32;         { 0x10 }
          length: integer32;              { 0x14 }
          reserved_18: array[16#18..16#73] of char;  { 0x18 }
          field_74: pinteger;             { 0x74 }
          reserved_76: array[16#76..16#87] of char;  { 0x76 }
          acl_uid: uid_$t);               { 0x88 }
      2: (longs: array[1..36] of integer32);
  end;

{ OS_$GET_REV_INFO - copy the kernel's revision record to the caller. }
procedure os_$get_rev_info(out info: os_$rev_t); extern;


{ ---- OS_$INIT's types and labels. ---- }

const
  { The startup statuses OS_$INIT raises (SR10.2's tables: OS /
    startup/shutdown, OS / MST manager); its crash calls pass them from
    cells after its code (os/init.pas). }
  status_$os_no_calendar_on_system = 16#001B0004;
                                          { "no calendar on system --
                                            please boot over network" }
  status_$os_cpu_board_below_minimum_revision_level = 16#001B0005;
                                          { "CPU board below minimum
                                            revision level" }
  { status_$mst_no_space_available (16#40003, "no space available"), the
    other status OS_$INIT crashes with, is mst/mst.ins.pas's (moved there
    in MST part 4; os/os.pas includes that insert first). }

type
  { The boot flags word, a word set: OS_$INIT tests its members on the
    word's low byte (member 4), member 15 as the word's sign, and
    intersects it with [2, 15]. }
  os_$boot_flags_t = set of 0..15;

  { The PROM's boot record, OS_$INIT's first parameter: nine longwords,
    copied whole.  With `boot_record_bus' the PROM gives the boot
    device's bus in the controller word's high byte; OS_$INIT moves it
    to `bus' and clears the byte through the second view. }
  os_$boot_info_t = record
    case integer of
      1: (device: integer;                { 0x00 }
          ctlr: integer;                  { 0x02 }
          unit: integer;                  { 0x04 }
          flags: os_$boot_flags_t;        { 0x06 }
          node_id: linteger;              { 0x08: the node id
                                            (`node_id_boot_record') }
          bus: integer;                   { 0x0C (`boot_record_bus') }
          reserved_0e: integer;           { 0x0E }
          reserved: array[1..5] of integer32);
                                          { 0x10..0x23 }
      2: (device_view: integer;           { 0x00 }
          ctlr_bus: char);                { 0x02: the controller word's
                                            high byte }
  end;

  { The diskless reply the bootstrap fetched, OS_$INIT's second
    parameter: twelve longwords, copied whole; OS_$INIT reads the
    mother node (+0x00), the paging file's UID (+0x04) and two more UIDs
    (+0x0C, +0x14). }
  os_$diskless_info_t = record
    case integer of
      1: (mother_node: linteger;          { 0x00: linteger, merged
                                            unmasked into the location
                                            descriptor's 20-bit node
                                            (OS_$INIT) }
          paging_file_uid: uid_$t;        { 0x04 }
          root_uid: uid_$t;               { 0x0C }
          node_uid: uid_$t;               { 0x14 }
          reserved: array[1..5] of integer32);
                                          { 0x1C..0x2F }
      { With `boot_flags_diskless', on a disked boot from the network
        (boot flag 8), the first two words are NET_IO_$BOOT_DEVICE's
        arguments. }
      2: (net_boot_device: integer;       { 0x00 }
          net_boot_unit: integer);        { 0x02 }
  end;

var
  { The image's layout labels that OS_$INIT builds the address space
    from (map symbols): their addresses are the immediates of OS_$INIT's
    moves, each a relocated cell: COLD, OS_LOW, OS_LOW_END (+16#7FFF),
    OS_BEGIN, OS_PROC (+16#3FF), OS_PROC_UNWIRED, OS_DATA_WIRED,
    OS_DATA_UNWIRED (also .DATA's start), OS_DATA_END (+16#7FFF),
    IODEFS_GUARD, IODEFS (DISP1_MEM at the same address,
    smd/smd.ins.pas).  Declared as characters: only their addresses are
    used.  MSTE_PAGES, whose address OS_$INIT uses too, is
    mst/mst_internal.ins.pas's (os/os.pas includes it). }
  cold: extern char;
  os_low: extern char;
  os_low_end: extern char;
  os_begin: extern char;
  os_proc: extern char;
  os_proc_unwired: extern char;
  os_data_wired: extern char;
  os_data_unwired: extern char;
  os_data_end: extern char;
  iodefs_guard: extern char;
  iodefs: extern char;
%if vm_65536_segs %then
  { VM_TABLES_END (map symbol): the end of the VM tables, below the low
    region; OS_$INIT frees the page maps of global B up to OS_LOW. }
  vm_tables_end: extern char;
%endif

  { The STACK segment's labels (the map's STACK data segment in the PAGE
    load section): the three guard pages OS_$INIT frees,
    NULL_STACK_GUARD, P1_STACK_GUARD and INT_STACK_GUARD, and
    INT_STACK_BASE, the top of the interrupt stack, below which it clears
    1 KB; each immediate a relocated cell.  NULL_PC, a longword of the
    same segment: OS_$INIT stores the null process's loop address into
    it, NULL_LOOP the first symbol of the map's NULLPROC data segment
    (hand assembly, os/m68k/nullproc.s).  Labels as characters, NULL_PC
    a pointer. }
  null_stack_guard: extern char;
  p1_stack_guard: extern char;
  int_stack_guard: extern char;
  int_stack_base: extern char;
  null_pc: extern univ_ptr;
  null_loop: extern char;

%if prom_config_record %then
type
  { A code in the PROM's configuration record: three bits after the
    byte's top bit, a packed record from the most significant bit. }
  os_$prom_code_t = packed record
    unused_7: boolean;                    { bit 7 }
    kind: 0..7;                           { bits 6..4 }
    unused_3_0: 0..15;                    { bits 3..0 }
  end;

  { A device as the PROM names it, 8 bytes: in the configuration record
    (the console's line, the console, the boot device, the network boot
    device), in its
    self-test list, and in a DCTE (+0x1C, io/io.ins.pas reserved_1c).
    Byte 0: kind (the code above's bits 6..4) and flags (valid; unit
    and ctlr given; in a self-test entry, failed); bytes 1 and 2 the
    unit and the controller; bytes 3..6 a four-character name (`R   '
    for the ring), compared whole.  A packed record: the name a
    byte-aligned longword at byte 3, which the MC68020 modes let cross
    two word boundaries (`[aligned(0)]'). }
  os_$prom_device_t = packed record
    failed: boolean;                      { bit 7 }
    kind: 0..7;                           { bits 6..4 }
    unused_3: boolean;                    { bit 3 }
    has_ctlr: boolean;                    { bit 2 }
    has_unit: boolean;                    { bit 1 }
    valid: boolean;                       { bit 0 }
    unit: 0..255;                         { 0x01 }
    ctlr: 0..255;                         { 0x02 }
    id: [aligned(0)] integer32;           { 0x03 }
    unused_07: char;                      { 0x07 }
  end;

type
  { An entry of the PROM's self-test list, 16 bytes: a device whose
    failed flag says how its self-test went; the list ends at the first
    entry not valid.  The 8 bytes after the device no routine reads. }
  os_$self_test_t = record
    device: os_$prom_device_t;            { 0x00 }
    unused_08: array[8..15] of char;      { 0x08 }
  end;
  os_$self_test_list_t = array[1..64] of os_$self_test_t;
  os_$self_test_list_ptr_t = ^os_$self_test_list_t;

  { The PROM's configuration record, OS_$INIT's third parameter, 0x38
    bytes, copied whole: the console's line (+0x09, a byte) and kind
    (+0x10; 4 a display), the boot device's kind (+0x18; 2 a tape), the
    list IO_$INIT and IO_$LOG_SELF_TESTS read (+0x2C) and the system
    clock's frequency (+0x34).  A variant record: OS_$INIT reads the
    codes and the console's line (1); IO_$INIT reads the devices whole
    (2), the fourth the network boot device. }
  os_$prom_config_t = record
    case integer of
      1: (unused_00: array[0..8] of char;         { 0x00 }
          console_line: [byte] 0..255;            { 0x09 }
          unused_0a: array[16#0A..16#0F] of char; { 0x0A }
          console: os_$prom_code_t;               { 0x10 }
          unused_12: integer;                     { 0x12 }
          unused_14: integer32;                   { 0x14 }
          boot_device: os_$prom_code_t;           { 0x18 }
          unused_1a: integer;                     { 0x1A }
          unused_1c: array[16#1C..16#2B] of char; { 0x1C }
          self_tests: os_$self_test_list_ptr_t;   { 0x2C }
          unused_30: integer32;                   { 0x30 }
          sys_freq: integer32);                   { 0x34 }
      2: (unused_v00: array[0..7] of char;        { 0x00 }
          line_dev: os_$prom_device_t;            { 0x08 }
          console_dev: os_$prom_device_t;         { 0x10 }
          boot_dev: os_$prom_device_t;            { 0x18 }
          net_dev: os_$prom_device_t);            { 0x20 }
  end;
  os_$prom_config_ptr_t = ^os_$prom_config_t;

const
  { The kinds OS_$INIT tests: the console a display (a workstation, not
    a server), the boot device a tape. }
  os_$prom_console_display = 4;
  os_$prom_boot_tape = 2;
%endif

%if crash_reboot %then
const
  { The PROM's restart code OS_$INIT leaves for OS_$SHUTDOWN when a
    server's node check shuts it down (CRASH reboots with it). }
  os_$restart_code_reboot = 243;
%endif

%if vector_alignment_check %then
const
  { 16#001B0009, "exception handler is not longword-aligned" (SR10.2's
    tables: OS / startup/shutdown). }
  status_$os_exception_handler_not_aligned = 16#001B0009;
%endif

{ OS_$INIT (OS_INIT_PROC; os/init.pas), entered from COLD's
  hand-written start-up (cold/<sau>/cold_start.s).  With
  `prom_config_record' the PROM's configuration record comes third, by
  address. }
%if prom_config_record %then
procedure os_$init(boot_info: os_$boot_info_t;
                   diskless: os_$diskless_info_t;
                   in prom_cfg: os_$prom_config_t);
  extern;
%else
procedure os_$init(boot_info: os_$boot_info_t;
                   diskless: os_$diskless_info_t);
  extern;
%endif

{ ---- The parts of other SAUs' start-up and shutdown
  (base/config.ins.pas). ---- }

%if power_off_check %then
{ OS_$INIT_POWER_OFF_CHECK (OS_INIT_PROC; os/init_power_off_check.pas). }
procedure os_$init_power_off_check; extern;

{ OS_$CHECK_POWER_OFF (WIRED_PROC; os/check_power_off.pas): the
  power-off check's time queue element's callback. }
procedure os_$check_power_off; extern;
%endif

%if gpu_driver %then
{ SMD_$GRAPHIC_DEVICE_ID and its values (smd_gdev_color2, _color3),
  which OS_$INIT and OS_$SHUTDOWN compare, are smd/smd.ins.pas's. }

%endif

%if disp2_probe %then
{ TODO(merge) misc/crash_system.ins.pas: DISP2_PRESENT

  DISP2_PRESENT (map symbol in CRASH_SYSTEM's data, the SAU4..SAU6):
  whether a second display answered OS_$INIT's probe, a boolean byte,
  stored from TESTPAGE's result and tested for its sign. }
var
  disp2_present: extern boolean;
%endif
