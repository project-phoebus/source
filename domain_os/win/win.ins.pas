{ win/win.ins.pas - WIN_ (the Winchester disk driver) constants, types,
  variables and routine headings, for the Domain Pascal tree.

  The driver's disk statuses, the drive's register block, the unit
  record, the statistics block, the status bytes, the module's
  map-symbol variables and its globals' headings; the layouts are the
  image's (no customer insert file declares them).

  Include base/base.ins.pas, ec/ec.ins.pas, io/io.ins.pas and
  disk/disk.ins.pas before it.
}

const
  { The statuses only this driver returns (the texts of the status-code
    database, stcode.db.10.2): 16#80015 "disk seek error" (SEEK returns
    it, WIN_$DO_IO tests for it), 16#80022 "disk driver logic error"
    (WIN_$CHECK_DISK_STATUS passes it to CRASH_SYSTEM), 16#80023 "unknown
    error status from drive" (win_$sense_general_status), 16#80024
    "unrecognized drive id" (DISK_INIT). }
  status_$disk_seek_error = 16#00080015;
  { status_$disk_driver_logic_error (16#00080022) is declared in
    disk/disk.ins.pas, which win.pas includes before this file (DISK_'s
    third unit, whose DISK_$DISMOUNT crashes with it, uses it too). }
  status_$unknown_error_status_from_drive = 16#00080023;
  status_$unrecognized_drive_id = 16#00080024;

type
  { An unsigned byte (suma's and disk's form). }
  win_$byte_t = [byte] 0..255;

%if win_descriptor_ctlr %then
{ ---- The descriptor-list controller (`win_descriptor_ctlr',
  base/config.ins.pas; the SAU5's driver).  The controller's window,
  through the unit record's pointer: a command byte, a status word, a
  table of drive parameters the controller fills, and a list of
  transfer descriptors the driver fills before the command.  The offsets
  are the routines'. ---- }

const
  { 16#80027 "ecc error in sector id field" (stcode.db.10.2;
    win_$check_disk_status), this driver's only.  16#80016 "drive timed
    out before operation completed" is disk/disk.ins.pas's
    status_$drive_timed_out. }
  status_$ecc_error_in_sector_id = 16#00080027;

  { The controller's commands (win_$command's byte): 1 seek (SEEK), 2
    transfer the descriptor list (WIN_$DO_IO), 3 format a track
    (win_$format_track), 5 restore (RESTORE), 8 read the drive's
    parameters (WIN_$DINIT). }
  win_cmd_seek = 1;
  win_cmd_transfer = 2;
  win_cmd_format = 3;
  win_cmd_restore = 5;
  win_cmd_read_params = 8;

  { The configuration word WIN_$CINIT writes to probe the controller and
    WIN_$DINIT stores at +0x300. }
  win_config_word = 16#3D05;

type
  { One drive's parameters in the controller's table, 8 bytes from
    +0x10: the drive type (0 none, 1..6 the drives WIN_$DINIT knows, 15
    none either), the cylinder count, the head count, the sectors per
    track, and a word WIN_$DINIT sets to 10000 and reports or takes as
    the label's word (pvlabel_info.w_04). }
  win_$drive_t = record
    dtype: win_$byte_t;                   { 0x00 }
    pad_01: char;
    cyls: pinteger;                       { 0x02 }
    heads: win_$byte_t;                   { 0x04 }
    spt: win_$byte_t;                     { 0x05 }
    w_06: pinteger;                       { 0x06 }
  end;

  { A transfer descriptor, 12 bytes: the request's cylinder, head and
    sector, its buffer's physical address and the page's number (the
    low word of the request's ppn), and the drive word (the drive unit
    plus 8, plus 4 for a write). }
  win_$desc_t = record
    cyl: pinteger;                        { 0x00 }
    head: win_$byte_t;                    { 0x02 }
    sector: win_$byte_t;                  { 0x03 }
    phys: integer32;                      { 0x04 }
    page: pinteger;                       { 0x08 }
    drive: pinteger;                      { 0x0A }
  end;

  { The ECC pattern the controller reports, two bytes (win_$ecc_correct
    copies it whole into a local). }
  win_$ecc_pattern_t = array[1..2] of win_$byte_t;

  { The window.  `[device]': the status word is read at each interrupt.
    The fields:
    - 0x00 go: 1, the start (WIN_$INT, WIN_$DINIT);
    - 0x01 command: the command byte (win_$command);
    - 0x02 status: the status word (WIN_$INT);
    - 0x04 count: the number of descriptors (1 for a seek, a restore, a
      format, the request count for a transfer);
    - 0x05 error: the error code of a failed command (WIN_$INT);
    - 0x08, 0x0A: the transfer's words 16#10 and 16#200 (WIN_$DO_IO);
    - 0x10 drives: the two drives' parameters;
    - 0x20 rev: the controller's revision (WIN_$DINIT,
      RETRY_DATA_CHECK);
    - 0x22 w_22: cleared before a transfer;
    - 0x24, 0x25 the controller's counts of corrected data checks and of
      overruns (win_$check_disk_status adds and clears them);
    - 0x26 ecc_pos, 0x28 ecc_pattern: where and what to correct
      (win_$ecc_correct);
    - 0x30 timeout_st: the word WIN_$INT copies to WIN_$TIMEOUT_ST;
    - 0x80 desc: the descriptors, from 1;
    - 0x300 config: the configuration word.
    Fillers between. }
  win_$regs_t = [device] record
    go: win_$byte_t;                      { 0x00 }
    command: win_$byte_t;                 { 0x01 }
    status: pinteger;                     { 0x02 }
    count: win_$byte_t;                   { 0x04 }
    error: win_$byte_t;                   { 0x05 }
    pad_06: integer;                      { 0x06 }
    w_08: pinteger;                       { 0x08 }
    w_0a: pinteger;                       { 0x0A }
    pad_0c: integer32;                    { 0x0C }
    drives: array[0..1] of win_$drive_t;  { 0x10 }
    rev: win_$byte_t;                     { 0x20 }
    pad_21: char;
    w_22: pinteger;                       { 0x22 }
    dc_count: win_$byte_t;                { 0x24 }
    ov_count: win_$byte_t;                { 0x25 }
    ecc_pos: integer;                     { 0x26 }
    ecc_pattern: win_$ecc_pattern_t;     { 0x28 }
    pad_2a: array[1..3] of integer;       { 0x2A }
    timeout_st: pinteger;                 { 0x30 }
    pad_32: array[1..39] of integer;      { 0x32 }
    desc: array[1..50] of win_$desc_t;    { 0x80 }
    pad_2d8: array[1..20] of integer;     { 0x2D8 }
    config: pinteger;                     { 0x300 }
  end;
%elseif win_atbus_ctlr %then
{ ---- The AT bus controller (`win_atbus_ctlr', base/config.ins.pas; the
  WIN8_ driver).  The controller takes a 6-byte command block through
  its data port, one byte at a time, when its status port shows the
  command phase; the data of a transfer passes through the controller's
  sector buffer by program (WIN_ASM), and the completion byte and the
  sense bytes come back through the same port.  The status port's
  value, less 16#C0, is the phase win_wait waits for. ---- }

const
  { 16#80027 "ecc error in sector id field" (stcode.db.10.2), a sense
    code win_$check_status maps; its other statuses are disk/disk.ins.pas's
    and this file's. }
  status_$ecc_error_in_sector_id = 16#00080027;

  { The controller's commands, the command block's first byte. }
  win_cmd_test_ready = 16#00;
  win_cmd_sense = 16#03;
  win_cmd_format_track = 16#06;
  win_cmd_init_drive = 16#0C;
  win_cmd_read_buffer = 16#0E;
  win_cmd_write_buffer = 16#0F;
  win_cmd_read = 16#1E;
  win_cmd_write = 16#1F;
  win_cmd_read_badspots = 16#37;
  win_cmd_drive_params = 16#EC;

  { The phases win_wait waits for: the status port's low bits. }
  win_phase_idle = 0;
  win_phase_data_out = 9;
  win_phase_data_in = 11;
  win_phase_command = 13;
  win_phase_status = 15;

  { The status port's value with a completion byte waiting (the status
    phase with both high bits), and the mask that finds it. }
  win_status_completion = 16#CF;

  { The control port's values: the controller's interrupt on and off. }
  win_ctl_int_on = 2;
  win_ctl_int_off = 0;

type
  { The controller's ports, through the unit record's pointer.
    `[device]': each access is a port access, in the order written, and
    a constant is stored as a constant (ref 3.15.3).  The fields:
    - 0x00 data: the command block's bytes out, the completion byte in,
      the sense and parameter words in and out as a word (data_w);
    - 0x01 status: the phase in the low bits, 16#C0 set; bit 5 the
      controller's interrupt;
    - 0x02 select: written 0 before a command block; the drive type in
      its low four bits;
    - 0x03 ctl: the interrupt's enable (win_ctl_int_on, _off). }
  win_$regs_t = [device] record
    case integer of
      1: (data: win_$byte_t;              { 0x00 }
          status: win_$byte_t;            { 0x01 }
          select: win_$byte_t;            { 0x02 }
          ctl: win_$byte_t);              { 0x03 }
      2: (data_w: integer);               { 0x00 }
  end;

  { The command block, 6 bytes, sent byte by byte (bytes):
    - byte 0 op: the command (win_cmd_...);
    - byte 1: cyl_10, set for a cylinder of 1024 and up; the drive (unit);
      the head;
    - bytes 2..3: the cylinder, stored whole (cyl) and shifted left 6
      with its low byte kept, which leaves its bits 9..8 in cyl_98; the
      sector in byte 2's low six bits;
    - byte 4: the count of sectors (count), or a format's interleave in
      two halves;
    - byte 5 ctl: the control byte: 0 for win_cmd_read_buffer, else
      step 1; ctl_7 and ctl_6 cleared by WIN8_$DINIT. }
  win_$cmd_t = packed record
    case integer of
      1: (op: win_$byte_t;                { 0x00 }
          cyl_10: boolean;                { 0x01 bit 7 }
          unit: 0..3;                     { 0x01 bits 6..5 }
          head: 0..31;                    { 0x01 bits 4..0 }
          cyl: integer;                   { 0x02 }
          count: win_$byte_t;             { 0x04 }
          ctl: win_$byte_t);              { 0x05 }
      2: (pad_00: integer;                { 0x00 }
          cyl_98: 0..3;                   { 0x02 bits 7..6 }
          sector: 0..63;                  { 0x02 bits 5..0 }
          cyl_lo: win_$byte_t;            { 0x03 }
          interleave_hi: 0..15;           { 0x04 bits 7..4 }
          interleave_lo: 0..15;           { 0x04 bits 3..0 }
          ctl_7: boolean;                 { 0x05 bit 7 }
          ctl_6: boolean;                 { 0x05 bit 6 }
          ctl_53: 0..7;                   { 0x05 bits 5..3 }
          step: 0..7);                    { 0x05 bits 2..0 }
      3: (bytes: array[0..5] of win_$byte_t);
  end;

  { The sense bytes win_cmd_sense returns, 4 bytes read as two words:
    valid, set when the sector is the failing one's; the error code;
    then the command block's bytes 1..3 for the failing sector. }
  win_$sense_t = packed record
    case integer of
      1: (valid: 0..1;                    { 0x00 bit 7 }
          unused_06: 0..1;                { 0x00 bit 6 }
          code: 0..63;                    { 0x00 bits 5..0 }
          b1: win_$byte_t;                { 0x01 }
          cyl_98: 0..3;                   { 0x02 bits 7..6 }
          sector: 0..63;                  { 0x02 bits 5..0 }
          cyl_lo: win_$byte_t);           { 0x03 }
      2: (w: array[1..2] of integer);
  end;

  { A drive's parameters, 10 bytes: the block win_cmd_init_drive takes
    (8 bytes: the cylinders, the heads, the reduced write current and the
    write precompensation cylinders, the ECC burst length), and the five
    words win_cmd_drive_params returns over the same bytes (the
    cylinders, heads and sectors less one in bytes 0..3; a sector size
    flag, the sign of the word at 4; bit 1 of byte 5; bytes 6..9 the
    label information's). }
  win_$params_t = packed record
    case integer of
      1: (cyls: integer;                  { 0x00 }
          heads: win_$byte_t;             { 0x02 }
          rwc: 0..65535;                  { 0x03 }
          precomp: 0..65535;              { 0x05 }
          ecc: win_$byte_t;               { 0x07 }
          w_08: integer);                 { 0x08 }
      2: (w: array[1..5] of integer);     { 0x00 }
      3: (w_00: integer;                  { 0x00 }
          w_02: integer;                  { 0x02 }
          w_04: integer);                 { 0x04 }
      4: (b: array[0..9] of win_$byte_t); { 0x00 }
  end;

  { The label information WIN8_$DINIT returns, 10 bytes: one longword or
    two words, then the precompensation word, a word nothing writes, and
    a word 1 for drive type 12. }
  win_$pvlabel_t = record
    case integer of
      1: (l_00: integer32;                { 0x00 }
          w_04: pinteger;                 { 0x04 }
          w_06: pinteger;                 { 0x06 }
          w_08: pinteger);                { 0x08 }
      2: (w_00: pinteger;                 { 0x00 }
          w_02: pinteger);                { 0x02 }
  end;

  { A request's buffer address as a page number and the offset in the
    page (PARITY_$SET_STATE's and PARITY_$CHK_IO's first page). }
  win_$phys_addr_t = packed record
    ppn: 0..16#3FFFFF;                    { bits 31..10 }
    offset: 0..1023;                      { bits 9..0 }
  end;

  { The controller's kind-3 DCTE (io/dctes.pas WIN8_DCTE) as this form
    reads it: the controller number, the unit's request (IO_$MAP_CSR's,
    IO_$ACQUIRE's; the ports' address its CSR page's) and the high word
    of the disk error queue longword at 0x48, the ML lock of WIN8_$DINIT
    and WIN8_$DO_IO and DISK_$REGISTER's `flags'. }
  win_$dcte_t = record
    kind: pinteger;                       { 0x00 }
    length: pinteger;                     { 0x02 }
    ctype: pinteger;                      { 0x04 }
    cnum: pinteger;                       { 0x06 }
    nextp: univ_ptr;                      { 0x08 }
    csrsytr: univ_ptr;                    { 0x0C }
    cstatus: status_$t;                   { 0x10 }
    name: array[1..8] of char;            { 0x14 }
    reserved_1c: array[1..12] of char;    { 0x1C }
    req: io_$acquire_rec_t;               { 0x28 }
    unused_46: integer;                   { 0x46 }
    lock: integer;                        { 0x48 }
    unused_4a: integer;                   { 0x4A }
  end;
  win_$dcte_ptr_t = ^win_$dcte_t;
%else

  { The drive's register block, through the unit record's pointer.
    `[device]': the status word is polled in WAIT_FOR_CONTROLLER's loop,
    re-read for each test, and the constants are stored as constants,
    never by a clear (ref 3.15.3).  The fields:
    - 0x00 command: the ANSI command byte stored (win_$ansi_command) and
      read back as the drive's extended status (WIN_$CHECK_DISK_STATUS);
    - 0x02 param: the parameter byte in or out (win_$ansi_command;
      DISK_INIT stores 1);
    - 0x06 status: the controller's status word, read as a whole; the
      same address is written as a byte, the sector of a transfer and 0
      before a format (read_or_write_disk_record, WIN_$FORMAT_TRACK): the
      second variant's sector;
    - 0x08 cylinder: the target cylinder word (SEEK);
    - 0x0A head: the target head byte (SEEK);
    - 0x0C mode: written 0, 9, 10 (WIN_$INT,
      read_or_write_disk_record, SEEK);
    - 0x0E go: the command type, 5 ANSI, 6 initialize, 8 select the head,
      4 seek, 3 format, 1 and 2 transfer, 0 idle.
    The bytes no routine names are fillers; two variants over the record,
    as flp/flp.ins.pas's register block (the status word and the sector
    byte share 0x06).  The offsets are the routines'. }
  win_$regs_t = [device] record
    case integer of
      1: (command: win_$byte_t;           { 0x00 }
          pad_01: char;
          param: win_$byte_t;             { 0x02 }
          pad_03: char;  { 0x03: (layout) three chars, not a
                                            3-char array, which is word
                                            aligned (ref 3.10.5.5) and
                                            moved status .. go by 2 }
          pad_04: char;
          pad_05: char;
          status: pinteger;               { 0x06 }
          cylinder: pinteger;             { 0x08 }
          head: win_$byte_t;              { 0x0A }
          pad_0b: char;
          mode: win_$byte_t;              { 0x0C }
          pad_0d: char;
          go: win_$byte_t);               { 0x0E }
      2: (pad_00b: array[0..5] of char;
          sector: win_$byte_t);           { 0x06: written }
  end;
%endif
  win_$regs_ptr_t = ^win_$regs_t;

%if win_atbus_ctlr %then
  { A controller's record, 12 bytes (WIN_$CINIT, WIN8_$DINIT index them
    by the controller number with a stride of 12): its DCTE and its
    ports, which WIN_$CINIT stores.  The last 4 bytes are addressed by
    nothing (the other forms' lock and unit words). }
  win_$unit_t = record
    dcte: win_$dcte_ptr_t;                { 0x00 }
    regs: win_$regs_ptr_t;                { 0x04 }
    unused_08: integer32;                 { 0x08 }
  end;

  { A drive's statistics, 22 bytes (WIN8_$GET_STATS copies five
    longwords and a word).  The counters, by the routines that change
    them:
    - 0x00 reads, 0x04 writes: the sectors read and written (WIN8_$DO_IO
      adds a run's count, or one a sector, and takes one off for each
      request of a failed chain);
    - 0x0A timeouts: a transfer's interrupt not in time (WIN8_$DO_IO);
    - 0x0C seek_errors, 0x0E equip_checks, 0x10 not_ready, 0x12
      data_checks: the sense codes win_check_status maps (WIN8_$DINIT
      takes back a not-ready of drive 1); data_checks also counts a
      completion byte with an error bit but bit 1;
    - 0x14 late_completions: a completion byte found waiting after the
      chain (WIN8_$DO_IO);
    - 0x08: a word no routine addresses. }
  win_$stats_t = record
    reads: integer32;                     { 0x00 }
    writes: integer32;                    { 0x04 }
    w_08: pinteger;                       { 0x08 }
    timeouts: pinteger;                   { 0x0A }
    seek_errors: pinteger;                { 0x0C }
    equip_checks: pinteger;               { 0x0E }
    not_ready: pinteger;                  { 0x10 }
    data_checks: pinteger;                { 0x12 }
    late_completions: pinteger;           { 0x14 }
  end;

  { TODO(pascal) the statistics array's 24-byte elements

    The drives' statistics are 24 bytes apart while a drive's record is
    22 (WIN8_$GET_STATS copies 22 bytes of it): the array pads each
    element to a multiple of 4, which the reference does not describe
    and dpc does not do (it lays the elements 22 bytes apart).  The
    element here is a record of the 22 bytes and a word nothing
    addresses, so the layout and the copy are the image's; whether the
    original declared the array of the 22-byte record alone is open. }
  win_$stats_slot_t = record
    stats: win_$stats_t;                  { 0x00 }
    unused_16: integer;                   { 0x16 }
  end;
%else
  { The unit record at the module block's start, 12 bytes (DISK_INIT
    indexes the units with a stride of 12).  WIN_$CINIT fills it from
    the DCTE (the DCTE's address, its register block's address, its
    lock word) and sets two members of the word at 0x0A, 13 and 11 (in
    the word's first byte), whose address it then passes as
    DISK_$REGISTER's integer `units': a set and an integer over the
    word, the variant part.  The lock word at 0x08 is the ML lock of
    WIN_$DINIT and WIN_$DO_IO and DISK_$REGISTER's `flags'. }
  win_$unit_t = record
    dcte: dcte_ptr_t;                     { 0x00 }
    regs: win_$regs_ptr_t;                { 0x04 }
    lock: integer;                        { 0x08 }
    case integer of                       { 0x0A }
      1: (unit_bits: set of 0..15);       { 0x0A }
      2: (units: integer);                { 0x0A }
  end;
%endif

  { The statistics block WIN_$CNT, 22 bytes (WIN_$GET_STATS copies five
    longwords and a word).  The counters, by the routines that bump
    them:
    - 0x00, 0x04: transfers, a longword each (read_or_write_disk_record:
      0x00 for an operation other than 2, 0x04 for operation 2);
    - 0x08 not_ready (wait_for_controller, WIN_$CHECK_DISK_STATUS);
    - 0x0C seek_errors (win_$sense_general_status);
    - 0x0E equip_checks (win_$sense_general_status,
      WIN_$CHECK_DISK_STATUS);
    - 0x12 data_checks (WIN_$CHECK_DISK_STATUS);
    - 0x14 dma_overruns (WIN_$CHECK_DISK_STATUS);
    - 0x0A, 0x10: words no routine addresses.
    A record whose fields are word aligned (ref 3.10.5.5, p. 3-26:
    objects longer than a byte on word boundaries), so its size is 22. }
  win_$cnt_t = record
    xfer_other: integer32;                { 0x00 }
    xfer_op2: integer32;                  { 0x04 }
    not_ready: pinteger;                  { 0x08 }
    w_0a: pinteger;                       { 0x0A }
    seek_errors: pinteger;                { 0x0C }
    equip_checks: pinteger;               { 0x0E }
    w_10: pinteger;                       { 0x10 }
    data_checks: pinteger;                { 0x12 }
    dma_overruns: pinteger;               { 0x14 }
  end;

%if win_descriptor_ctlr %then
var
  { The map symbols inside the map's WIN_ data segment (WIRED_DATA,
    0x78 bytes, as the SAU2's but laid out otherwise), defined in
    win/win.pas:
    - WIN_$CNT (+0x40), the statistics block (WIN_$GET_STATS copies it;
      here w_0a counts controller time-outs and w_10 drive time-outs);
    - WIN_$FIXES (+0x58), the count of corrected ECC errors, a longword
      (win_$ecc_correct bumps it);
    - WIN_$RESTORES (+0x5C), the count of restores (RESTORE bumps it);
    - WIN_$DT (+0x68), a longword WIN_$SPIN_DOWN tests: when zero it
      restores the drive first (no WIN_ routine writes it);
    - WIN_$TIMEOUT_ST (+0x72), the controller's time-out word as WIN_$INT
      last saw it.
    Only WIN_'s own code addresses the block. }
  win_$cnt: extern win_$cnt_t;
  win_$fixes: extern integer32;
  win_$restores: extern integer32;
  win_$dt: extern integer32;
  win_$timeout_st: extern pinteger;

  { WIN_ECC_BUF (map symbol, in DISK_BUFFERS): the buffer the data of a
    sector past the block header goes to, which win_$ecc_correct maps
    the request's page at to correct a byte. }
  win_ecc_buf: extern array[0..1023] of win_$byte_t;

{ Routine headings, in map order: the map's WIN_ code segments in
  WIRED_PROC and in OS_INIT_PROC.  The map symbols without `$'
  (RESTORE, SEEK, RETRY_DATA_CHECK) are globals.  The module-local
  routines' headings are in their fragments. }

{ RESTORE - recalibrate a drive. }
function restore(in ctlr: pinteger; in dev_unit: pinteger): integer32;
  extern;

{ SEEK - position the drive for a request: select its head, then seek its
  cylinder. }
function seek(in ctlr: pinteger; in dev_unit: pinteger;
              in cyl: pinteger): integer32;
  extern;

{ RETRY_DATA_CHECK - the recovery step for a data check. }
function retry_data_check(in ctlr: pinteger; in dev_unit: pinteger;
                          in retry: integer): integer32;
  extern;
%elseif win_atbus_ctlr %then
var
  { WIN_$CNT (map symbol inside the map's WIN_ data segment, WIRED_DATA,
    0x380 bytes, at +0x340), defined in win/win.pas: a statistics record
    no routine addresses. }
  win_$cnt: extern win_$stats_t;

  { WIN_PAGE (map symbol, in the BUFFER_PAGES region): the page a
    sector's data is mapped at for WIN_ASM. }
  win_page: extern array[0..1023] of char;

%else
  { The drive's general status as WIN_$CHECK_DISK_STATUS keeps it, 2
    bytes: the byte the drive reports (from REPORT GENERAL STATUS or the
    command register) and one more.  WIN_$ATTN has this type: its first
    byte is cleared, and the whole is stored from the routine's local, a
    2-byte record assignment; the local is passed whole by value to
    win_$sense_general_status, which reads the first byte from the high
    half of its slot.  The second byte is never named (its contents are
    the local's uninitialized byte). }
  win_$attn_t = record
    gen: win_$byte_t;                     { 0x00 }
    b1: win_$byte_t;                      { 0x01 }
  end;

  { The two ANSI report bytes win_$sense_general_status reads into
    WIN_$SENSE: cleared together by one word store, each then the output
    byte of one command, and tested bit by bit.  A word and the two
    bytes, a variant record. }
  win_$sense_t = record
    case integer of
      1: (w: pinteger);                   { 0x00 }
      2: (b0: win_$byte_t;                { 0x00 }
          b1: win_$byte_t);               { 0x01 }
  end;

  { The geometry words DISK_INIT returns ([0] always 0, [1] the cylinder
    count reported), from 0. }
  win_$geometry_t = array[0..1] of pinteger;

  { The module's pointer to a volume (the block's +0x5C; the current
    request's, +0x60, is disk/disk.ins.pas's disk_$io_req_ptr_t). }
  win_$vol_ptr_t = ^disk_$volume_t;

var
  { The map symbols inside the map's WIN_ data segment (WIRED_DATA,
    0x78 bytes), defined in win/win.pas:
    - WIN_$CNT (+0x40), the statistics block (WIN_$GET_STATS copies it);
    - WIN_$KTHUNKD (+0x64), the count of drive re-initializations, a
      longword (win_$reinit_drive bumps it);
    - WIN_$ATTN (+0x6C), the general status (win_$attn_t);
    - WIN_$CSTAT (+0x6E), the last controller status word
      (WIN_$CHECK_DISK_STATUS stores it);
    - WIN_$SENSE (+0x70), the two report bytes (win_$sense_t).
    Only WIN_'s own code addresses the block. }
  win_$cnt: extern win_$cnt_t;
  win_$kthunkd: extern integer32;
  win_$attn: extern win_$attn_t;
  win_$cstat: extern pinteger;
  win_$sense: extern win_$sense_t;

{ Routine headings, in map order: the map's WIN_ code segments in
  WIRED_PROC and in OS_INIT_PROC.  The map symbols without `$' (SEEK,
  DISK_INIT) are globals too.  The bodies repeat the full heading (ref
  7.3.4, Method 2).  The module-local routines' headings are in their
  fragments. }

{ SEEK - position the drive for a request: select its head, then seek its
  cylinder. }
function seek(unit: pinteger; dev_unit: pinteger; in req: disk_$io_req_t;
              wait: boolean): integer32;
  options(extern, val_param);
%endif

%if win_atbus_ctlr %then
{ Routine headings, in map order: the map's WIN_ code segment in
  WIRED_PROC (WIN_$SPIN_DOWN, then the module-local routines, whose
  headings are in their fragments, then WIN8_$DO_IO .. WIN8_$GET_STATS),
  WIN_ASM, and WIN_ in OS_INIT_PROC (WIN_$CINIT). }

{ WIN_$SPIN_DOWN - stop the drive's spindle. }
function win_$spin_down(in unit: pinteger): integer;
  extern;

{ WIN8_$DO_IO - the driver's I/O entry: format a track, read the
  manufacturer's bad spots, or run a chain of read and write requests. }
procedure win8_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                      in param_3: univ integer32; out result: boolean);
  extern;

{ WIN8_$DINIT - the unit initialization entry. }
function win8_$dinit(unit: pinteger; ctlr: pinteger;
                     var num_blocks: integer32;
                     out sec_per_track: pinteger; out num_heads: pinteger;
                     out pvlabel_info: win_$pvlabel_t;
                     out flags: pinteger): integer32;
  options(extern, val_param);

{ WIN8_$INT - the controller's interrupt routine. }
function win8_$int(in dcte: win_$dcte_t): boolean;
  extern;

{ WIN8_$ERROR_QUE - the error queue entry: the driver has none. }
procedure win8_$error_que(in vol: disk_$volume_t; is_timeout: integer;
                          out result: boolean);
  options(extern, val_param);

{ WIN8_$GET_STATS - the statistics entry. }
procedure win8_$get_stats(cnum: integer; unit: pinteger;
                          out stats: win_$stats_t);
  options(extern, val_param);

{ WIN_$FILL_CTL_BUF and WIN_$EMPTY_CTL_BUF (WIN_ASM, hand assembly,
  win/sau8/win_asm.s): move a sector's header (16 words) and data (512
  words) to and from the controller's data port.  Each argument is a
  pointer, by address: the header's, the data's and the ports' for
  FILL; the ports', the header's and the data's for EMPTY. }
procedure win_$fill_ctl_buf(in hdr: univ_ptr; in data: univ_ptr;
                            in regs: win_$regs_ptr_t);
  extern;
procedure win_$empty_ctl_buf(in regs: win_$regs_ptr_t; in hdr: univ_ptr;
                             in data: univ_ptr);
  extern;

{ WIN_$CINIT - the Winchester controller's initialization. }
function win_$cinit(var dcte: win_$dcte_t): integer32;
  extern;
%else
{ WIN_$DO_IO - the driver's I/O entry: format a track, or run a chain of
  read and write requests. }
procedure win_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                     in param_3: univ integer32; out result: boolean);
  extern;

%if not win_descriptor_ctlr %then
{ DISK_INIT - bring a drive up and find its geometry. }
function disk_init(unit: pinteger; sub_unit: integer;
                   var total_blocks: integer32;
                   var blocks_per_track: pinteger; var heads: pinteger;
                   out geometry: win_$geometry_t;
                   out drive_id: pinteger): integer32;
  options(extern, val_param);
%endif

{ WIN_$SPIN_DOWN - stop the drive's spindle. }
function win_$spin_down(in unit: pinteger): integer;
  extern;

{ WIN_$INT - the Winchester controller's interrupt routine. }
function win_$int(in dcte: dcte_t): boolean;
  extern;

%if win_descriptor_ctlr %then
{ WIN_$DINIT - the unit initialization entry. }
function win_$dinit(unit: pinteger; ctlr: pinteger;
                    var num_blocks: integer32;
                    out sec_per_track: pinteger; var num_heads: pinteger;
                    var pvlabel_info: disk_$pvlabel_info_t;
                    out flags: pinteger): integer32;
  options(extern, val_param);
%else
{ WIN_$DINIT - the unit initialization entry. }
function win_$dinit(unit: pinteger; ctlr: pinteger;
                    var num_blocks: integer32;
                    var sec_per_track: pinteger; var num_heads: pinteger;
                    out pvlabel_info: win_$geometry_t;
                    out flags: pinteger): integer32;
  options(extern, val_param);
%endif

{ WIN_$ERROR_QUE - the error queue entry: the Winchester driver has none. }
procedure win_$error_que(in vol: disk_$volume_t; is_timeout: integer;
                         out result: boolean);
  options(extern, val_param);

{ WIN_$GET_STATS - the statistics entry. }
procedure win_$get_stats(cnum: integer; unit: integer;
                         out stats: win_$cnt_t);
  options(extern, val_param);

{ WIN_$CINIT - the Winchester controller's initialization. }
function win_$cinit(var dcte: dcte_t): integer32;
  extern;
%endif
