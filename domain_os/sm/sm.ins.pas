{ sm/sm.ins.pas - SM_ (the storage module disk driver) constants, types,
  variables and routine headings, for the Domain Pascal tree.

  The SM module (sm/sm.pas) drives the storage module disks through the
  PBU's storage module controller, on the SAUs whose kernel has the
  storage module drivers (the part smd_disk, base/config.ins.pas).  It
  shares the controller's command block, SM_$CB in the PBU's
  hand-written page, with the SM_C module (sm_c/).  No customer insert
  file declares any of it.

  Include base/base.ins.pas, ec/ec.ins.pas, time/time.ins.pas,
  misc/crash_system.ins.pas, ml/ml.ins.pas, io/io.ins.pas,
  disk/disk.ins.pas and win/win.ins.pas (the disk statuses) before it;
  the PBU's routines, PBU_$MCB and IOMAP are pbu/pbu.ins.pas's.
}

const
  { 16#80016 "drive timed out before operation completed" is
    disk/disk.ins.pas's status_$drive_timed_out. }

  { The PBU unit number of the storage module controller, the first
    argument of every PBU_ call and DISK_$REGISTER's device type, and
    the probe kind TESTPAGE is given for the controller's go register. }
  sm_pbu_unit = 4;
  sm_probe_kind = 2;

  { The commands the routines put in the command block (cmd, +0x30) and
    issue: 0 at reset, 1 to read the unit's error block, 2 to format, 4
    read, 6 write, 8 seek, 15 to start a unit (DINIT). }
  sm_cmd_reset = 0;
  sm_cmd_sense = 1;
  sm_cmd_format = 2;
  sm_cmd_read = 4;
  sm_cmd_write = 6;
  sm_cmd_seek = 8;
  sm_cmd_start = 15;

  { The last drive (four drives on the controller; the reset loop and
    SM_$SPIN_DOWN step through them). }
  sm_max_unit = 3;

  { The I/O map entries the driver writes, 4 bytes each from IOMAP: the
    command block's page and the transfer's buffer page.  The entry is the
    physical page number plus 16#48000 (the long_iomap part,
    base/config.ins.pas). }
  sm_iomap_cb = 16#1BD;
  sm_iomap_buf = 16#1BE;
  sm_iomap_bias = 16#48000;

type
  { A byte the controller and the driver share (an unsigned 8-bit value). }
  sm_$byte_t = [byte] 0..255;

  { The status word a unit's command leaves (+0x02 of a drive record),
    in its two views: the bits (bit 2: the unit stopped; bit 6: an
    error block is there to read) and the controller's 2-bit state in
    bits 7..6 of its low byte, nonzero when the command did not simply
    succeed. }
  sm_$status_t = packed record
    case integer of
      1: (bits: set of 0..15);
      2: (unused_15_8: 0..255;            { bits 15..8 }
          state: 0..3;                    { bits 7..6 }
          unused_5_0: 0..63);             { bits 5..0 }
  end;

  { A unit's error block (+0x0C of a drive record, 12 bytes), which the
    sense command fills: the error word, whose bits check_status sorts
    into statuses, and the byte at +3 with the data, seek and equipment
    bits. }
  sm_$err_block_t = record
    err: set of 0..15;                    { 0x00 }
    unused_02: sm_$byte_t;                { 0x02 }
    err2: sm_$byte_t;                     { 0x03 }
    unused_04: array[1..4] of integer;    { 0x04 }
  end;

  { A drive's record in the command block, 0x3C bytes, from +0x50: the
    ready flag, the parity error flag the interrupt sets, the status
    word, the drive's parameters (8 bytes, their address given to the
    controller at reset), the error block, the completion eventcount,
    and the counters SM_$GET_STATS returns. }
  sm_$drive_t = record
    ready: boolean;                       { 0x00 }
    parity_err: boolean;                  { 0x01 }
    status: sm_$status_t;                 { 0x02 }
    params: array[1..2] of integer32;     { 0x04 }
    err_block: sm_$err_block_t;           { 0x0C }
    ec: ec_$eventcount_t;                 { 0x18 }
    stats: disk_$stats_t;                 { 0x24 }
    unused_3a: integer;                   { 0x3A }
  end;

  { The command word at +0x30: the command, then the unit in the low two
    bits of the next byte. }
  sm_$cmd_word_t = packed record
    cmd: sm_$byte_t;                      { bits 15..8, +0x30 }
    unused_7_2: 0..63;                    { bits 7..2 }
    unit: 0..3;                           { bits 1..0, +0x31 }
  end;

  { The interrupt word at +0x16: the unit the interrupt is for in bits
    5..4 of its low byte; the whole word is the unit's status. }
  sm_$int_word_t = packed record
    case integer of
      1: (all: sm_$status_t);
      2: (unused_15_6: 0..1023;           { bits 15..6 }
          unit: 0..3;                     { bits 5..4 }
          unused_3_0: 0..15);             { bits 3..0 }
  end;

  { The flags word at +0x44: bit 15, the driver's code and data are
    wired. }
  sm_$cb_flags_t = packed record
    wired: boolean;                       { bit 15 }
    unused_14_0: 0..16#7FFF;              { bits 14..0 }
  end;

  { ---- The SM_C controller's view of the same page (sm_c/). ---- }

  { The controller's status word (+0x02 of the block, +0x02 of a unit
    record): the whole word, and its low byte, the status code
    sm_c_$check_status sorts. }
  sm_c_$status_t = packed record
    case integer of
      1: (all: pinteger);
      2: (unused_hi: sm_$byte_t;          { bits 15..8 }
          code: sm_$byte_t);              { bits 7..0 }
  end;

  { The word at +0x04: the transfer mode in the low three bits of its
    first byte, then the unit. }
  sm_c_$mode_unit_t = packed record
    unused_7_3: 0..31;                    { bits 15..11 }
    mode: 0..7;                           { bits 10..8, +0x04 }
    unit: sm_$byte_t;                     { bits 7..0, +0x05 }
  end;

  { The four bytes at +0x06: the head and sector bytes, then the
    cylinder's low and high bytes; cleared as one longword, its first
    word or-ed with 16#FFFF. }
  sm_c_$daddr_t = record
    case integer of
      1: (all: integer32);
      2: (hs: pinteger;                   { 0x00 }
          cyl_lo: sm_$byte_t;             { 0x02 }
          cyl_hi: sm_$byte_t);            { 0x03 }
      3: (head: sm_$byte_t;               { 0x00 }
          sector: sm_$byte_t);            { 0x01 }
  end;

  { The ECC information the controller leaves at +0x14: four bytes, or
    the longword SM_C_$DO_IO clears. }
  sm_c_$ecc_t = record
    case integer of
      1: (all: integer32);
      2: (b0: sm_$byte_t;                 { 0x00 }
          b1: sm_$byte_t;                 { 0x01 }
          b2: sm_$byte_t;                 { 0x02 }
          b3: sm_$byte_t);                { 0x03 }
  end;

  { A unit's flags word (+0x00 of a unit record): ready (bit 15, the
    drive came up), the parity error the interrupt saw (bit 14), and the
    controller's command register as the interrupt read it (the low
    byte). }
  sm_c_$unit_flags_t = packed record
    ready: boolean;                       { bit 15 }
    parity_err: boolean;                  { bit 14 }
    unused_13_8: 0..63;                   { bits 13..8 }
    cmd_reg: sm_$byte_t;                  { bits 7..0 }
  end;

  { A unit's record, 0x28 bytes, from +0x18 of the page (the routines
    index the page by 40 × unit: +0x18 the flags, +0x1C the eventcount,
    +0x28 the counters SM_C_$GET_STATS returns). }
  sm_c_$unit_t = record
    flags: sm_c_$unit_flags_t;            { 0x00 }
    status: sm_c_$status_t;               { 0x02 }
    ec: ec_$eventcount_t;                 { 0x04 }
    stats: disk_$stats_t;                 { 0x10 }
    unused_26: integer;                   { 0x26 }
  end;

  { A sector entry of the format table at +0xB8, a 32-bit packed record:
    the cylinder's low byte, the sector number's high two bits, three
    bits zero, the cylinder's high three bits, the head, two bits zero,
    the sector number's low six bits. }
  sm_c_$fmt_entry_t = packed record
    cyl_lo: 0..255;                       { bits 31..24 }
    sec_hi: 0..3;                         { bits 23..22 }
    zero_3: 0..7;                         { bits 21..19 }
    cyl_hi: 0..7;                         { bits 18..16 }
    head: 0..255;                         { bits 15..8 }
    zero_2: 0..3;                         { bits 7..6 }
    sec_lo: 0..63;                        { bits 5..0 }
  end;

  { SM_$CB, the PBU page's storage module command block (the
    hand-written data: SM_$CB at +0, SM_$CNT at +0x74), in the two
    controllers' layouts: the SM controller's (the first variant, 0x150
    bytes: SM_$CINIT clears 336 bytes when the controller is absent)
    and the SM_C controller's (the second: the command bytes, the unit
    records from +0x18, 40 bytes apart, the format table from +0xB8; 46
    entries reach PBU_$MCB, the page's next object, and the count the
    routines use is not bounded in the image).

    busy is `[volatile]': the controller clears it.  A volatile field
    does not make the record volatile (ref 3.15.7), so the unit records
    are copied whole.  The fields the routines use; the others are the
    controllers'. }
  sm_$cb_t = record
    case integer of
      1: (unused_00: array[1..7] of char;       { 0x00 }
          busy: [volatile] sm_$byte_t;          { 0x07 }
          unused_08: array[1..7] of integer;    { 0x08 }
          int_word: sm_$int_word_t;             { 0x16 }
          unused_18: char;                      { 0x18 }
          int_ack: sm_$byte_t;                  { 0x19 }
          unused_1a: array[1..11] of integer;   { 0x1A }
          cmd_word: sm_$cmd_word_t;             { 0x30 }
          cmd_param: sm_$byte_t;                { 0x32 }
          unused_33: char;                      { 0x33 }
          cyl: pinteger;                        { 0x34 }
          sector: sm_$byte_t;                   { 0x36 }
          head: sm_$byte_t;                     { 0x37 }
          buf_offset: pinteger;                 { 0x38 }
          unused_3a: integer;                   { 0x3A }
          xfer_word: pinteger;                  { 0x3C }
          unused_3e: array[1..3] of integer;    { 0x3E }
          flags: sm_$cb_flags_t;                { 0x44 }
          alloc_count: pinteger;                { 0x46 }
          alloc: integer32;                     { 0x48 }
          unused_4c: integer32;                 { 0x4C }
          drive: array[0..sm_max_unit] of sm_$drive_t;  { 0x50 }
          fmt_block: array[1..6] of integer;    { 0x140 }
          go_ack: sm_$byte_t;                   { 0x14C }
          go_cmd: sm_$byte_t;                   { 0x14D }
          probe: sm_$byte_t;                    { 0x14E }
          unused_14f: char);                    { 0x14F }
      2: (c_cmd: sm_$byte_t;                    { 0x00 }
          c_op: sm_$byte_t;                     { 0x01 }
          c_status: sm_c_$status_t;             { 0x02 }
          c_mode_unit: sm_c_$mode_unit_t;       { 0x04 }
          c_daddr: sm_c_$daddr_t;               { 0x06 }
          c_count: sm_$byte_t;                  { 0x0A }
          c_id: sm_$byte_t;                     { 0x0B }
          c_buf_lo: sm_$byte_t;                 { 0x0C }
          c_buf_mid: sm_$byte_t;                { 0x0D }
          c_b0e: sm_$byte_t;                    { 0x0E }
          c_buf_hi: sm_$byte_t;                 { 0x0F }
          c_b10: sm_$byte_t;                    { 0x10 }
          c_b11: sm_$byte_t;                    { 0x11 }
          c_unused_12: integer;                 { 0x12 }
          c_ecc: sm_c_$ecc_t;                   { 0x14 }
          c_unit: array[0..sm_max_unit] of sm_c_$unit_t;  { 0x18 }
          c_fmt: array[0..45] of sm_c_$fmt_entry_t);      { 0xB8 }
  end;

  { The command block as 336 bytes, from 1 (SM_$CINIT's clear). }
  sm_$cb_bytes_t = array[1..336] of char;
  sm_$cb_bytes_ptr_t = ^sm_$cb_bytes_t;

  { The controller's register page at PBU_SM_PAGE: the go register at
    +0x340, which the driver writes with the command block's go bytes
    and TESTPAGE probes.  `[device]'. }
  sm_$page_t = [device] record
    unused_000: array[1..416] of integer;   { 0x000 }
    go: sm_$byte_t;                       { 0x340 }
  end;

  { What PBU_$GET_PTR returns for the controller:
    +0x24, the eventcount the PBU advances at an interrupt (SM_$INT sets
    it to the unit's).  The size past it is not seen. }
  sm_$pbu_info_t = record
    unused_00: array[1..9] of integer32;  { 0x00 }
    int_ec: univ_ptr;                     { 0x24 }
  end;
  sm_$pbu_info_ptr_t = ^sm_$pbu_info_t;

  { The controller's block header buffer, at the DCTE's io_va (+0x2C):
    SM_$DO_IO copies a request's eight-longword header to it before a
    write and from it after a read. }
  sm_$hdr_ptr_t = ^disk_$info_t;

var
  { SM_$CB (map symbol, in the PBU page's hand-written PBU_ASM data). }
  sm_$cb: extern sm_$cb_t;

  { PBU_SM_PAGE (map symbol of the I/O definitions, no `$'). }
  pbu_sm_page: extern sm_$page_t;

  { SM_BLK_HDR (map symbol without `$', in PBU_ASM): the controller's
    block header area; only its address is used (IO_'s DCTES). }
  sm_blk_hdr: extern char;

  { The markers of the module's wired range (map symbols): SM_$PROC_START
    (the module's first byte), SM_$PROC_END (sm/m68k/end_addr.s),
    SM_$DATA_START (the data block's first byte) and SM_$DATA_END (the
    next segment's); only their addresses are used. }
  sm_$proc_start: extern char;
  sm_$proc_end: extern char;
  sm_$data_start: extern char;
  sm_$data_end: extern char;

{ ---- The module's global routines (sm/sm.pas), in map order. ---- }

{ SM_$INT - the storage module controller's interrupt routine. }
function sm_$int: integer; extern;

{ SM_$CINIT - initialize the storage module controller at boot. }
function sm_$cinit(var dcte: dcte_t): integer32; extern;

{ SM_$DINIT - bring a storage module drive up. }
function sm_$dinit(unit: pinteger; ctlr: pinteger;
                   var num_blocks: integer32;
                   var sec_per_track: pinteger; var num_heads: pinteger;
                   out pvlabel_info: univ disk_$pvlabel_info_t;
                   out flags: pinteger): integer32;
  options(extern, val_param);

{ SM_$GET_STATS - return a storage module drive's counters. }
procedure sm_$get_stats(cnum: integer; unit: pinteger;
                        out stats: univ disk_$stats_t);
  options(extern, val_param);

{ SM_$DO_IO - perform a disk request on a storage module drive. }
procedure sm_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                    in param_3: univ integer32; out result: boolean);
  extern;

{ SM_$REVALIDATE - mark a storage module drive ready again. }
procedure sm_$revalidate(in vol: disk_$volume_t); extern;

{ SM_$SPIN_DOWN - warn about storage module drives still spinning. }
function sm_$spin_down(in ctlr: pinteger): integer; extern;
