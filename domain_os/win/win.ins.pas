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
    WIN_$DINIT stores at +0x300: the turbo boards' controller
    (`win_vectored_ctlr') takes another. }
%if win_vectored_ctlr %then
  win_config_word = 16#1B05;

  { The status word's bit WIN_$INT tests: the controller's interrupt. }
  win_status_int = 16#800;
%else
  win_config_word = 16#3D05;
%endif

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
%if win6_ct6_board %then

{ ---- The second Winchester and tape controller (`win6_ct6_board',
  base/config.ins.pas; the WIN6_ driver, beside the descriptor-list
  one).  The board's 32 KB page holds 250 command blocks (IOPBs) of 32
  bytes from +0x6000, chained by a link word, of which the driver keeps
  a free list (WIN6_$GET_IOPBS, WIN6_$RTN_IOPBS), and a mailbox area
  near its end: the start word takes the offset of a chain's first
  block, the completion word gives the offset of the chain the
  controller finished, and two more words report the controller's
  other two interrupts.  A block the controller rejects comes back
  with its status bytes set, an error block (EPB).  The cartridge tape
  driver CT6_ uses the same page and blocks. ---- }

const
  { 16#80028 "disk subsystem detected a DC powerfail" (stcode.db.10.2),
    one of the error blocks' statuses. }
  status_$disk_dc_powerfail = 16#00080028;

  { The command blocks: the last one's number, and the link word of the
    last block of a chain (a link is the next block's offset from the
    first block, its number times 32). }
  win6_last_iopb = 249;
  win6_iopb_size = 32;
  win6_end_of_chain = -1;

  { A block's operation byte: read, write, format a track, the drive's
    parameters, the two drive commands WIN6_$ERROR_QUE gives before a
    retry (the seek takes the drive's geometry), and a format of the
    drive (DISK_$FORMAT's request, at the drive's last cylinder).  The
    seek and the recalibration go to the head of the start queue. }
  win6_op_read = 16#00;
  win6_op_write = 16#10;
  win6_op_format_track = 16#14;
  win6_op_drive_params = 16#22;
  win6_op_seek_geometry = 16#40;
  win6_op_recalibrate = 16#41;
  win6_op_format = 16#86;

  { A format block's code byte (+0x17). }
  win6_format_code = 16#37;

  { A block's state word (+0x08), its low bits: handed out, started,
    done (both); a transfer's options word: the request is
    checksummed. }
  win6_state_used = 1;
  win6_state_started = 2;
  win6_state_done = 3;
  win6_opt_chksum = 16#20;

  { An error block's severity: none, recovered, failed, and the
    controller's answer to a block it did not take. }
  win6_sev_none = 0;
  win6_sev_recovered = 1;
  win6_sev_failed = 2;
  win6_sev_rejected = 3;

  { An error block's class (the low four bits of its byte at +0x04): the
    command, the drive, the controller, the bus, the board. }
  win6_class_command = 0;
  win6_class_drive = 1;
  win6_class_ctlr = 2;
  win6_class_bus = 3;
  win6_class_board = 4;

  { win6_$epb_status's action: what WIN6_$ERROR_QUE does with the failed
    request (none, a retry, a correction of the data); WIN6_$ERROR_QUE's
    own: a retry after a recalibration or after a seek to the drive's
    geometry, and none set yet. }
  win6_act_none = 0;
  win6_act_retry = 1;
  win6_act_recal = 2;
  win6_act_seek = 3;
  win6_act_ecc = 4;
  win6_act_unset = -1;

  { The controller's initialization status byte once it has run: 0, or
    16#80. }
  win6_init_ok = 0;
  win6_init_ok_2 = 16#80;

  { The start queue's length (RQ, a ring from 1) and the error logs':
    WIN6_$INT_ERS (LOG_INT_ERROR's words) and WIN6_$EPBS
    (win6_$epb_status's copies of the error blocks). }
  win6_rq_size = 128;
  win6_int_ers_size = 40;
  win6_epbs_size = 64;

type
  { An error block's status bytes (+0x04): the severity, the class and
    the code. }
  win6_$err_t = packed record
    sev: 0..3;                            { 0x04 bits 7..6 }
    unused_54: 0..3;                      { 0x04 bits 5..4 }
    class: 0..15;                         { 0x04 bits 3..0 }
    code: win_$byte_t;                    { 0x05 }
  end;

  { The word at +0x0A: zero, written as two bytes or as the word. }
  win6_$f0a_t = record
    case integer of
      1: (b_0a: win_$byte_t;              { 0x0A }
          b_0b: win_$byte_t);             { 0x0B }
      2: (w: integer);                    { 0x0A }
  end;

  { The operation word (+0x06): the operation byte and the drive. }
  win6_$opu_t = packed record
    op: win_$byte_t;                      { 0x06 }
    unused_72: 0..63;                     { 0x07 bits 7..2 }
    unit: 0..3;                           { 0x07 bits 1..0 }
  end;

  { The drive's parameters a win6_op_drive_params block brings back
    (from +0x14). }
  win6_$drive_info_t = record
    unused_00: integer;                   { 0x14 }
    b_02: win_$byte_t;                    { 0x16 }
    unused_03: win_$byte_t;               { 0x17 }
    cyls: integer;                        { 0x18 }
    heads: win_$byte_t;                   { 0x1A }
    spt: win_$byte_t;                     { 0x1B }
    dtype: win_$byte_t;                   { 0x1C }
    unused_09: win_$byte_t;               { 0x1D }
    flags: win_$byte_t;                   { 0x1E }
    b_0b: win_$byte_t;                    { 0x1F }
  end;
  win6_$drive_info_ptr_t = ^win6_$drive_info_t;

  { A format block's parameters (+0x10): the track twice and the code. }
  win6_$format_t = record
    cyl: pinteger;                        { 0x10 }
    head: win_$byte_t;                    { 0x12 }
    zero_13: win_$byte_t;                 { 0x13 }
    cyl_2: pinteger;                      { 0x14 }
    head_2: win_$byte_t;                  { 0x16 }
    code: win_$byte_t;                    { 0x17 }
    zero_18: integer32;                   { 0x18 }
  end;
  win6_$format_ptr_t = ^win6_$format_t;

  { A drive's geometry, 4 bytes: WIN6_$DINIT keeps the cylinder count,
    the seek block takes the four bytes whole. }
  win6_$geom_t = record
    cyls: integer;                        { 0x00 }
    b_02: win_$byte_t;                    { 0x02 }
    b_03: win_$byte_t;                    { 0x03 }
  end;

  win6_$ecc_pattern_t = array[1..4] of win_$byte_t;

  { The board's command and error block, 32 bytes:
    - 0x00 req: the request it carries (WIN6_$INT follows it back);
    - 0x04 status: -1 when started; the controller's answer (err);
    - 0x06 the operation word; 0x08 state: the state bits and the
      options; 0x0A, 0x0B, 0x0C: zero; 0x0E link;
    - 0x10..0x1F the operation's parameters: a transfer's disk address,
      buffer and page addresses; a format's track; a seek's geometry;
      the drive's parameters (from +0x14); an error block's ECC
      position (+0x10) and pattern (+0x1C).
    The longword view (l) is WIN6_$CINIT's, which clears the error
    blocks. }
  win6_$iopb_t = record
    case integer of
      1: (req: disk_$io_req_ptr_t;        { 0x00 }
          case integer of
            1: (status: integer;          { 0x04 }
                opu: win6_$opu_t;         { 0x06 }
                state: integer;           { 0x08 }
                f_0a: win6_$f0a_t;        { 0x0A }
                w_0c: integer;            { 0x0C }
                link: integer;            { 0x0E }
                case integer of
                  1: (daddr: disk_$daddr_t;   { 0x10 }
                      phys: integer32;        { 0x14 }
                      buf: integer32;         { 0x18 }
                      l_1c: integer32);       { 0x1C }
                  2: (fmt: win6_$format_t);   { 0x10 }
                  3: (geom: win6_$geom_t);    { 0x10 }
                  4: (w_10: integer);         { 0x10 }
                  5: (l_10: integer32;        { 0x10 }
                      drive: win6_$drive_info_t);  { 0x14 }
                  6: (ecc_pos: integer;       { 0x10 }
                      pad_12: array[1..5] of integer;
                      ecc_pattern: win6_$ecc_pattern_t));  { 0x1C }
            2: (err: win6_$err_t));       { 0x04 }
      2: (l: array[1..8] of integer32);   { 0x00 }
  end;
  win6_$iopb_ptr_t = ^win6_$iopb_t;

  { A mailbox flag, bit 0 of its byte (a 1-byte packed record, 2
    bytes). }
  win6_$mbox_t = packed record
    unused_71: 0..127;                    { bits 7..1 }
    flag: 0..1;                           { bit 0 }
  end;

  { The board's page, `[device]': the controller reads and writes it,
    constants are stored as constants (ref 3.15.3).  The fields:
    - 0x6000 iopbs: the command blocks;
    - 0x7FB5..0x7FBB: the initialization's parameter bytes (WIN6_$CINIT;
      WIN6_$DINIT clears bits 0, 2 and 3 of 0x7FB9);
    - 0x7FBC init_go: 1 starts the initialization; 0x7FBD init_status;
    - 0x7FC0 start: set while the controller has not taken a start;
      0x7FC2 start_iopb, the offset of the chain to start;
    - 0x7FC4 done: a completion waiting; 0x7FC6 done_iopb, its chain's
      offset;
    - 0x7FD4 ctlr_int and 0x7FD6 ctlr_status, 0x7FDC async_int and
      0x7FDE async_status: the controller's other two interrupts.
    The bytes before the command blocks are the board's buffers. }
  win6_$page_t = [device] record
    data: array[0..16#5FFF] of win_$byte_t;   { 0x0000 }
    iopbs: array[0..win6_last_iopb] of win6_$iopb_t;  { 0x6000 }
    pad_7f40: array[0..16#74] of win_$byte_t; { 0x7F40 }
    init_b5: win_$byte_t;                 { 0x7FB5 }
    init_b6: win_$byte_t;                 { 0x7FB6 }
    init_b7: win_$byte_t;                 { 0x7FB7 }
    init_b8: win_$byte_t;                 { 0x7FB8 }
    init_b9: win_$byte_t;                 { 0x7FB9 }
    init_ba: win_$byte_t;                 { 0x7FBA }
    init_bb: win_$byte_t;                 { 0x7FBB }
    init_go: win_$byte_t;                 { 0x7FBC }
    init_status: win_$byte_t;             { 0x7FBD }
    pad_7fbe: integer;                    { 0x7FBE }
    start: win6_$mbox_t;                  { 0x7FC0 }
    start_iopb: integer;                  { 0x7FC2 }
    done: win6_$mbox_t;                   { 0x7FC4 }
    done_iopb: integer;                   { 0x7FC6 }
    pad_7fc8: array[1..6] of integer;     { 0x7FC8 }
    ctlr_int: win6_$mbox_t;               { 0x7FD4 }
    ctlr_status: integer;                 { 0x7FD6 }
    pad_7fd8: integer32;                  { 0x7FD8 }
    async_int: win6_$mbox_t;              { 0x7FDC }
    async_status: integer;                { 0x7FDE }
  end;
  win6_$page_ptr_t = ^win6_$page_t;

  { The error counts of one severity (WIN6_$ERRORS: recovered, failed),
    140 bytes: a word for each class's codes, from 1. }
  win6_$err_counts_t = record
    c0: array[1..7] of pinteger;          { 0x00 }
    c1: array[1..45] of pinteger;         { 0x0E }
    c2: array[1..10] of pinteger;         { 0x68 }
    c3: array[1..7] of pinteger;          { 0x7C }
    c4: array[1..1] of pinteger;          { 0x8A }
  end;
  win6_$errors_t = array[win6_sev_recovered..win6_sev_failed] of
    win6_$err_counts_t;
  win6_$epbs_t = array[1..win6_epbs_size] of win6_$iopb_t;

  { A drive's record, 280 bytes (indexed by the drive with a stride of
    280): the eventcount a parameters block advances; the interrupt
    watch (set at each completion with its clock, cleared by
    WIN6_$ERROR_QUE's time-out call); each process's failed request, by
    its DISK_BPTBL number, whose element 0 is the drive's geometry. }
  win6_$drive_t = record
    ec: ec_$eventcount_t;                 { 0x00 }
    int_seen: boolean;                    { 0x0C }
    int_time: integer32;                  { 0x0E }
    case integer of
      1: (geom: win6_$geom_t);            { 0x12 }
      2: (failed: array[0..64] of disk_$io_req_ptr_t;  { 0x12 }
          pad_116: integer);              { 0x116 }
  end;

  { WIN_$DT: the board's command blocks' address and their address on
    the bus (the crash dump reads them). }
  win_$dt_t = record
    iopbs: integer32;                     { 0x00 }
    iopbs_bus: integer32;                 { 0x04 }
  end;

  { The label information WIN6_$DINIT fills. }
  win6_$pvlabel_info_t = record
    w_00: pinteger;                       { 0x00 }
    w_02: pinteger;                       { 0x02 }
    w_04: pinteger;                       { 0x04 }
    w_06: pinteger;                       { 0x06 }
    w_08: pinteger;                       { 0x08 }
  end;
%endif
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

%elseif win_ring_disk_ctlr %then
{ ---- The ring/disk board's disk controller (`win_ring_disk_ctlr',
  base/config.ins.pas; the DN400/DN600 family's board, on the DNx60 the
  WIN page): up to four drives on a PRIAM interface or, with the unit
  record's smd_interface, an SMD interface, the transfers on two
  channels of the board's DMA controller, the block header's page and
  the data page.  The drive select's bits are active low on the PRIAM
  interface (255 less the drive's bit, 16 shl n, and the head), a field
  on the SMD interface (the drive in bits 6..4, bit 7 a strobe). ---- }

const
  { The drive's commands on the PRIAM interface (Domain Engineering
    Handbook, ch. 8, "PRIAM command register"); the SMD interface's
    take other values (DISK_INIT, seek). }
  win_cmd_sequence_up = 1;
  win_cmd_sequence_down = 2;
  win_cmd_restore = 3;
  win_cmd_seek = 4;
  win_cmd_fault_reset = 5;

  { The board's disk control values (ch. 8, "Disk control"): a read, a
    write or a format with the interrupt enabled, the interrupt alone,
    nothing. }
  win_ctl_read = 16#81;
  win_ctl_write = 16#41;
  win_ctl_format = 16#21;
  win_ctl_int = 16#01;
  win_ctl_off = 0;

  { The PRIAM interface's drive status bits (ch. 8, "PRIAM status
    register"): 7 command rejected, 6 write protected, 5 drive fault,
    4 busy, 3 on cylinder 0, 2 seek fault, 1 seek complete, 0 ready. }
  win_st_write_protect = 6;
  win_st_drive_fault = 5;
  win_st_busy = 4;
  win_st_cyl0 = 3;
  win_st_ready = 0;

  { The controller status bits (ch. 8, "Disk Controller Status"):
    7 busy, 6 not ready, 5 CRC error, 4 time-out, 1 bus error in the
    DMA, 0 DMA overrun. }
  win_cs_busy = 7;
  win_cs_crc_error = 5;
  win_cs_timeout = 4;
  win_cs_bus_error = 1;
  win_cs_overrun = 0;

type
  { The board's disk registers, a byte at each even address (ch. 8,
    "RING/DISK"), through the unit record's pointer; `[device]': each
    access is the hardware's, in the order written.  The fields:
    - 0x00 cyl_hi, 0x02 cyl_lo: the cylinder's high and low bytes, read
      back after a PRIAM seek;
    - 0x04 cmd: the drive's command register, read as its status (the
      second variant's status);
    - 0x06 head: the head number (the SMD interface's data byte);
    - 0x08 select: the drive and head select;
    - 0x0A sector: the sector;
    - 0x0C control: the disk control (win_ctl_...);
    - 0x10 ctlr_status: the controller status (win_cs_..., ctlr_bits);
    - 0x18 int_ack: the disk interrupt's acknowledge;
    - 0x40..0x46: the DMA controller's channel 0 address and count (the
      block header) and channel 1 address and count (the data), each
      written and read a byte at a time, low then high;
    - 0x50 dma_command, 0x54 dma_mask (the single mask), 0x56 dma_mode,
      0x58 dma_clear_ptr (the byte pointer's clear), 0x5A
      dma_master_clear. }
  win_$regs_t = [device] record
    case integer of
      1: (cyl_hi: win_$byte_t;            { 0x00 }
          pad_01: char;
          cyl_lo: win_$byte_t;            { 0x02 }
          pad_03: char;
          cmd: win_$byte_t;               { 0x04 }
          pad_05: char;
          head: win_$byte_t;              { 0x06 }
          pad_07: char;
          select: win_$byte_t;            { 0x08 }
          pad_09: char;
          sector: win_$byte_t;            { 0x0A }
          pad_0b: char;
          control: win_$byte_t;           { 0x0C }
          pad_0d: char;
          pad_0e: array[1..2] of char;
          ctlr_status: win_$byte_t;       { 0x10 }
          pad_11: char;
          pad_12: array[1..6] of char;
          int_ack: win_$byte_t;           { 0x18 }
          pad_19: char;
          pad_1a: array[1..38] of char;
          dma_addr0: win_$byte_t;         { 0x40 }
          pad_41: char;
          dma_count0: win_$byte_t;        { 0x42 }
          pad_43: char;
          dma_addr1: win_$byte_t;         { 0x44 }
          pad_45: char;
          dma_count1: win_$byte_t;        { 0x46 }
          pad_47: char;
          pad_48: array[1..8] of char;
          dma_command: win_$byte_t;       { 0x50 }
          pad_51: char;
          pad_52: array[1..2] of char;
          dma_mask: win_$byte_t;          { 0x54 }
          pad_55: char;
          dma_mode: win_$byte_t;          { 0x56 }
          pad_57: char;
          dma_clear_ptr: win_$byte_t;     { 0x58 }
          pad_59: char;
          dma_master_clear: win_$byte_t); { 0x5A }
      2: (pad_00b: array[0..3] of char;
          status: [byte] set of 0..7;     { 0x04 }
          pad_05b: char;
          pad_06b: array[1..10] of char;
          ctlr_bits: [byte] set of 0..7); { 0x10 }
  end;

  { An SMD drive's information record as DISK_INIT reads it from the
    drive command register, at most 32 bytes: the drive type, the heads,
    the cylinders, the blocks per track, two words DISK_INIT returns as
    the geometry, and the count of blocks it takes off the total in
    cylinders. }
  win_$smd_info_t = record
    case integer of
      1: (b: array[1..32] of win_$byte_t);
      2: (dtype: win_$byte_t;             { 0x00 }
          heads: win_$byte_t;             { 0x01 }
          cyls: pinteger;                 { 0x02 }
          spt: pinteger;                  { 0x04 }
          w_06: pinteger;                 { 0x06 }
          w_08: pinteger;                 { 0x08 }
          w_0a: pinteger);                { 0x0A }
  end;
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

%if win_mailbox_ctlr %then
{ ---- The mailbox controller (`win_mailbox_ctlr', base/config.ins.pas;
  the WIN7_ driver, beside the WIN8_ one).  Up to two controllers on
  the AT bus, each with a block of memory the driver maps into the bus
  through the I/O map: 62 outgoing and 62 incoming mailboxes, then
  18 command blocks of 68 bytes (WIN_$CB's mbox and iopb_pa).  The
  driver builds a command block (WIN_SETUP_IOPB), puts its bus address
  in the next outgoing mailbox (WIN_SETUP_MAILBOX) and writes the start
  command with the mailbox's number to the command port
  (WIN_SEND_COMMAND); the controller interrupts with the number of the
  incoming mailbox that holds the block's address and its completion
  code (WIN7_$INT).  A transfer's pages are mapped into a 16 KB window
  of the I/O map, one of 16 the driver hands out. ---- }

const
  { The bytes WIN_SEND_COMMAND writes to the command port: the
    initialization (followed by its parameter bytes, below), the second
    command WIN7_$DINIT gives after it, the request for an interrupt
    when an outgoing mailbox is free, and the start of the command
    block in the outgoing mailbox the low six bits name. }
  win7_ctl_initialize = 1;
  win7_ctl_enable = 2;
  win7_ctl_mbox_free_int = 4;
  win7_ctl_start = 16#80;

  { The initialization's parameter bytes, between its two leading
    zeros and the mailbox area's 3-byte bus address: 16#70 and 16#20;
    and the count of outgoing and of incoming mailboxes after it. }
  win7_init_param_1 = 16#70;
  win7_init_param_2 = 16#20;
  win7_mailboxes = 62;

  { The command blocks' operations (the block's byte 0). }
  win7_op_read = 16#20;
  win7_op_write = 16#30;
  win7_op_format_track = 16#50;
  win7_op_drive_params = 16#F4;
  win7_op_format = 16#F5;

  { The status port's bits: the command port ready, a command
    rejected, the controller initialized.  The interrupt status port:
    its two high bits are win7_int_mailbox when an incoming mailbox
    holds a completion (its number in the low six bits), win7_int_free
    when an outgoing mailbox is free. }
  win7_status_ready = 16#40;
  win7_status_rejected = 16#20;
  win7_status_initialized = 16#10;
  win7_int_mask = 16#C0;
  win7_int_mailbox = 16#C0;
  win7_int_free = 16#80;
  win7_int_mbox_number = 16#3F;

  { The control port's values: reset the controller; then its
    interrupt and its DMA on. }
  win7_ctl_reset = 1;
  win7_ctl_run = 12;

  { A completion code in an incoming mailbox: done; the codes of a
    failed block, which go to the failed list for WIN7_$ERROR_QUE. }
  win7_done = 1;
  win7_failed_2 = 2;
  win7_failed_3 = 3;
  win7_failed_16 = 16;
  win7_failed_17 = 17;
  win7_failed_18 = 18;

  { The window pool: 16 windows of 16 KB; win7_buf_index is 17 when
    all are taken. }
  win7_windows = 16;
  win7_window_size = 16384;

  { WIN7_$DINIT's drive identifiers by capacity (the flags it returns). }
  win7_id_small_7_heads = 16#603;
  win7_id_small = 16#607;
  win7_id_200000 = 16#60C;
  win7_id_400000 = 16#608;
  win7_id_800000 = 16#609;
  win7_id_2000000 = 16#60A;

type
  win7_$iopb_ptr_t = ^win7_$iopb_t;

  { A command block's record of the driver's own, 28 bytes, one per
    block (win7_infos): the block's bus address; the next and the
    previous block of the list it is on (WIN_$CB's free, busy and failed
    lists); the request it serves (its chain's first); its count of
    pages; the window's bus address (buf); the completion code the
    interrupt found (status); the block's length in bytes, the
    mailbox's first byte (length); the drive (unit); whether the block
    is in a mailbox (in_mbox) and the process that set it up
    (owner).  A packed record: length and unit are 16-bit fields at odd
    offsets. }
  win7_$info_t = packed record
    phys: integer32;                      { 0x00 }
    next: win7_$iopb_ptr_t;               { 0x04 }
    prev: win7_$iopb_ptr_t;               { 0x08 }
    req: disk_$io_req_ptr_t;              { 0x0C }
    count: win_$byte_t;                   { 0x10 }
    unused_11: win_$byte_t;               { 0x11 }
    buf: integer32;                       { 0x12 }
    status: win_$byte_t;                  { 0x16 }
    length: -32768..32767;                { 0x17 }
    unit: -32768..32767;                  { 0x19 }
    in_mbox: boolean;                     { 0x1B bit 7 }
    owner: 0..127;                        { 0x1B bits 6..0 }
  end;
  win7_$info_ptr_t = ^win7_$info_t;

  { A command block, 64 bytes the controller reads and writes, and the
    pointer to the driver's record of it at 0x40.  The bytes:
    - 0x00 op, the operation (win7_op_...); 0x01..0x04 the controller's
      completion bytes, cleared before the block is sent: 0x03 the
      drive's status (stat), 0x04 the error bits (error);
    - 0x05..0x0B for a transfer or a format: 0x06 the count of sectors
      (a format track's sectors per track), 0x07 the first sector,
      0x08..0x09 the cylinder, low byte first, 0x0A the drive and head
      (16#80 + drive * 16 + head), 0x0B the sectors done (cleared; the
      controller's count when a transfer failed);
    - from 0x0C, addr: the data's 3-byte bus address, the high byte
      first; for a transfer, the headers' addresses follow, 3 bytes each
      from 0x0F;
    - for the drive's parameters (win7_op_drive_params), the reply's
      fields from 0x0B: the cylinders plus one at 0x0D, the heads at
      0x12, the precompensation cylinder at 0x15, the sectors per track
      at 0x18; the other fields are cleared before the block is sent. }
  win7_$iopb_t = packed record
    case integer of
      1: (op: win_$byte_t;                { 0x00 }
          b_01: win_$byte_t;              { 0x01 }
          b_02: win_$byte_t;              { 0x02 }
          stat: win_$byte_t;              { 0x03 }
          error: win_$byte_t;             { 0x04 }
          b_05: win_$byte_t;              { 0x05 }
          count: win_$byte_t;             { 0x06 }
          sector: win_$byte_t;            { 0x07 }
          cyl_lo: win_$byte_t;            { 0x08 }
          cyl_hi: win_$byte_t;            { 0x09 }
          drive_head: win_$byte_t;        { 0x0A }
          done: win_$byte_t;              { 0x0B }
          addr: array[0..51] of win_$byte_t;
                                          { 0x0C: 3-byte addresses }
          info: win7_$info_ptr_t);        { 0x40 }
      2: (pad_00: array[0..10] of win_$byte_t;
                                          { 0x00..0x0A }
          w_0b: 0..65535;                 { 0x0B }
          cyls: 0..65535;                 { 0x0D }
          w_0f: 0..65535;                 { 0x0F }
          b_11: win_$byte_t;              { 0x11 }
          heads: win_$byte_t;             { 0x12 }
          w_13: 0..65535;                 { 0x13 }
          precomp: 0..65535;              { 0x15 }
          b_17: win_$byte_t;              { 0x17 }
          sectors: win_$byte_t;           { 0x18 }
          w_19: 0..65535;                 { 0x19 }
          b_1b: win_$byte_t;              { 0x1B }
          b_1c: win_$byte_t;              { 0x1C }
          b_1d: win_$byte_t;              { 0x1D }
          b_1e: win_$byte_t;              { 0x1E }
          b_1f: win_$byte_t;              { 0x1F }
          b_20: win_$byte_t;              { 0x20 }
          b_21: win_$byte_t;              { 0x21 }
          b_22: win_$byte_t;              { 0x22 }
          b_23: win_$byte_t;              { 0x23 }
          b_24: win_$byte_t;              { 0x24 }
          b_25: win_$byte_t;              { 0x25 }
          b_26: win_$byte_t;              { 0x26 }
          b_27: win_$byte_t;              { 0x27 }
          b_28: win_$byte_t;              { 0x28 }
          b_29: win_$byte_t;              { 0x29 }
          b_2a: win_$byte_t;              { 0x2A }
          w_2b: 0..65535;                 { 0x2B }
          b_2d: win_$byte_t);             { 0x2D }
      3: (bytes: array[0..63] of win_$byte_t);
                                          { 0x00 }
  end;

  { A mailbox, 4 bytes: the completion code (or 0 when free) and the
    command block's 3-byte bus address; cleared as a pointer. }
  win7_$mbox_entry_t = packed record
    case integer of
      1: (all: univ_ptr);
      2: (status: win_$byte_t;            { 0x00 }
          hi: win_$byte_t;                { 0x01 }
          mid: win_$byte_t;               { 0x02 }
          lo: win_$byte_t);               { 0x03 }
      3: (w: integer32);
  end;

  { The mailbox area, 496 bytes: the outgoing mailboxes, then the
    incoming (at 0xF8). }
  win7_$mbox_t = record
    case integer of
      1: (out: array[0..61] of win7_$mbox_entry_t;
                                          { 0x00 }
          inb: array[0..61] of win7_$mbox_entry_t);
                                          { 0xF8 }
      2: (all: array[0..123] of win7_$mbox_entry_t);
  end;
  win7_$mbox_ptr_t = ^win7_$mbox_t;

  { The controller's ports, through WIN_$CB's regs (`[device]'): the
    command port (written) and the status port (read) at 0x00; the
    interrupt status (read) and its acknowledgement (written 1) at
    0x01; the control port at 0x02. }
  win7_$regs_t = [device] record
    cmd: win_$byte_t;                     { 0x00 }
    int: win_$byte_t;                     { 0x01 }
    ctl: win_$byte_t;                     { 0x02 }
  end;
  win7_$regs_ptr_t = ^win7_$regs_t;

  { A drive's record in WIN_$CB, 36 bytes: its statistics (the
    22-byte record of the WIN8_ driver), the geometry the drive reported
    (win7_op_drive_params) and whether it has. }
  win7_$drive_t = record
    stats: win_$stats_t;                  { 0x00 }
    heads: pinteger;                      { 0x16 }
    sectors: pinteger;                    { 0x18 }
    unused_1a: integer;                   { 0x1A }
    cyls: pinteger;                       { 0x1C }
    precomp: pinteger;                    { 0x1E }
    unused_20: integer;                   { 0x20 }
    valid: boolean;                       { 0x22 }
  end;
  win7_$drive_ptr_t = ^win7_$drive_t;

  { A process's record for a drive: its command blocks in the
    controller (count), and the flags: member 15 its chain's last block
    sent, member 14 a block failed. }
  win7_$proc_unit_t = record
    count: integer;                       { 0x00 }
    flags: set of 0..15;                  { 0x02 }
  end;

  { A controller's record, one of WIN_$CB's two, 640 bytes: the drives;
    the command blocks' lists (free, busy, failed: done) and the block
    being set up (cur), under the spin lock; the interrupt's vector word
    (vector) and the ports' bus address (csr_pa) of the DCTE's request;
    the ports (regs); the block's bus addresses (map_base, the mailbox
    area's; iopb_pa, the command blocks'); the mailbox area (mbox); the
    DCTE's ML lock; the DMA channel; IO_$ACQUIRE's unit; whether the
    record is set up (initialized); the next outgoing mailbox
    (mbox_index); and the processes' records (procs), indexed by the
    process number and the drive.

    The processes' array, as the image indexes it, starts 0x54 bytes
    into the record, so its records of processes 1 to 5 overlay the
    fields from cur on. }
  win7_$ctlr_t = record
    case integer of
      1: (drives: array[0..1] of win7_$drive_t;
                                          { 0x00 }
          free: win7_$iopb_ptr_t;         { 0x48 }
          busy: win7_$iopb_ptr_t;         { 0x4C }
          done: win7_$iopb_ptr_t;         { 0x50 }
          cur: win7_$iopb_ptr_t;          { 0x54 }
          spin: integer32;                { 0x58 }
          vector: integer32;              { 0x5C }
          regs: win7_$regs_ptr_t;         { 0x60 }
          csr_pa: integer32;              { 0x64 }
          map_base: integer32;            { 0x68 }
          iopb_pa: integer32;             { 0x6C }
          mbox: win7_$mbox_ptr_t;         { 0x70 }
          lock: integer;                  { 0x74 }
          dma_channel: integer;           { 0x76 }
          unit: io_$unit_num_t;           { 0x78 }
          initialized: boolean;           { 0x7A }
          mbox_index: integer);           { 0x7C }
      2: (unused_00: array[1..21] of integer32;
                                          { 0x00..0x53 }
          procs: array[1..64] of array[0..1] of win7_$proc_unit_t;
                                          { 0x54 }
          unused_254: array[1..11] of integer32);
                                          { 0x254..0x27F }
  end;
  win7_$ctlr_ptr_t = ^win7_$ctlr_t;

  { A slot of the format's sector table (win7_sg): a zero byte and the
    sector's number. }
  win7_$sector_slot_t = record
    flag: win_$byte_t;                    { 0x00 }
    sector: win_$byte_t;                  { 0x01 }
  end;

  { A longword and its bytes, the high one first: how the driver takes
    an address or a cylinder apart into a command block's bytes. }
  win7_$bytes_t = packed record
    case integer of
      1: (l: integer32);
      2: (b0: win_$byte_t;
          b1: win_$byte_t;
          b2: win_$byte_t;
          b3: win_$byte_t);
  end;

  { The start command WIN_SETUP_MAILBOX returns, a longword, and its
    low word, which WIN7_$DO_IO hands WIN_SEND_COMMAND. }
  win7_$start_t = record
    case integer of
      1: (l: integer32);
      2: (hi: integer;
          lo: integer);
  end;

  { The page lists WIN_SETUP_IOPB hands IOMAP_$MAP and WP_$CALLOC_LIST
    fills. }
  win7_$ppn_list_t = array[1..32] of integer32;
%endif
%else
%if win_ring_disk_ctlr %then
  { The ring/disk controller's unit word as WIN_$CINIT stores bit 12:
    smd_interface, set when the controller answers its SMD interface's
    probe (the drive types of class 16#200, the PRIAM's otherwise); the
    routines test it as unit_bits' member win_smd_interface. }
  win_$unit_flags_t = packed record
    unused_15_13: 0..7;                   { bits 15..13 }
    smd_interface: boolean;               { bit 12 }
    unused_11_0: 0..4095;                 { bits 11..0 }
  end;

const
  { unit_bits' member 12: the SMD interface (win_$unit_flags_t). }
  win_smd_interface = 12;

type
%endif
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
%if win_ring_disk_ctlr %then
      3: (flags: win_$unit_flags_t);      { 0x0A }
%endif
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
%if win6_ct6_board %then
  win_$dt: extern win_$dt_t;
%else
  win_$dt: extern integer32;
%endif
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
%if win6_ct6_board %then

var
  { The WIN6_ driver's map symbols in the map's WIN_ data segment
    (WIRED_DATA, 0xD54 bytes with the descriptor-list driver's), defined
    in win/win.pas:
    - WIN6_$INT_ERS, LOG_INT_ERROR's log of the controller's other
      interrupts' words, and WIN6_$INT_ERX, its last entry;
    - WIN6_$EPBS, win6_$epb_status's copies of the error blocks, and
      WIN6_$EPBX, the last one's number;
    - WIN6_$ERRORS, the error counts by severity, class and code;
    - RQ, the start queue of the blocks waiting for the controller, a
      ring of RQST (its head, the next taken) and RQND (its tail), RQCNT
      the blocks in it, CTL_BSY true while a start is the controller's;
    - WIN6_$FIXES, the count of corrected data checks; WIN6_$RETRIES, a
      failed request's retries (10), WIN6_$FIX_ECCC, whether a data
      check is corrected (true). }
  win6_$int_ers: extern array[1..win6_int_ers_size] of integer;
  win6_$epbs: extern win6_$epbs_t;
  win6_$errors: extern win6_$errors_t;
  rq: extern array[1..win6_rq_size] of integer;
  win6_$fixes: extern integer32;
  win6_$int_erx: extern integer;
  win6_$epbx: extern integer;
  win6_$retries: extern pinteger;
  rqnd: extern integer;
  rqst: extern integer;
  rqcnt: extern integer;
  win6_$fix_eccc: extern boolean;
  ctl_bsy: extern boolean;

{ WIN6_$GET_IOPBS - hand out a chain of command blocks. }
function win6_$get_iopbs(n: integer; out first: integer;
                         out last: integer): integer32;
  options(extern, val_param);

{ WIN6_$RTN_IOPBS - give a chain of command blocks back. }
procedure win6_$rtn_iopbs(n: integer; first: integer; last: integer);
  options(extern, val_param);

{ WIN6_$GET_ERROR_INFO - copy out the error counts and the error log. }
procedure win6_$get_error_info(out errors: win6_$errors_t;
                               out epbx: integer;
                               out epbs: win6_$epbs_t);
  extern;

{ WIN6_$INT - the second controller's completion interrupt. }
function win6_$int(in dcte: dcte_t): boolean;
  extern;

{ LOG_INT_ERROR - log a word of the controller's other interrupts. }
procedure log_int_error(in w: integer);
  extern;

{ WIN6_$ASYNC_INT, WIN6_$CTLR_INT - the controller's other two
  interrupts. }
function win6_$async_int(in dcte: dcte_t): boolean;
  extern;
function win6_$ctlr_int(in dcte: dcte_t): boolean;
  extern;

{ WIN6_$DINIT - the unit initialization entry. }
function win6_$dinit(unit: pinteger; ctlr: pinteger;
                     var num_blocks: integer32;
                     out sec_per_track: pinteger; var num_heads: pinteger;
                     var pvlabel_info: win6_$pvlabel_info_t;
                     out flags: pinteger): integer32;
  options(extern, val_param);

{ WIN6_$DO_IO - the driver's I/O entry. }
procedure win6_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                      in param_3: univ integer32; out result: boolean);
  extern;

{ WIN6_$ERROR_QUE - the error queue entry: retry or finish a process's
  failed request. }
procedure win6_$error_que(in vol: disk_$volume_t; is_timeout: integer;
                          out result: boolean);
  options(extern, val_param);
%endif
%elseif win_atbus_ctlr %then
var
  { WIN_$CNT (map symbol inside the map's WIN_ data segment, WIRED_DATA,
    0x380 bytes, at +0x340), defined in win/win.pas: a statistics record
    no routine addresses. }
  win_$cnt: extern win_$stats_t;

  { WIN_PAGE (map symbol, in the BUFFER_PAGES region): the page a
    sector's data is mapped at for WIN_ASM. }
  win_page: extern array[0..1023] of char;
%if win_mailbox_ctlr %then

  { WIN_$CB (map symbol inside the WIN_ data segment, at +0x5D0),
    defined in win/win.pas: the two mailbox controllers' records. }
  win_$cb: extern array[0..1] of win7_$ctlr_t;

  { RAW_BUF (map symbol, the DISK_BUFFERS region's buffer at its +0x10000):
    the virtual address at which WIN7_$DINIT maps the controllers'
    mailbox areas and command blocks. }
  raw_buf: extern array[0..1023] of char;
%endif

%else
%if not win_ring_disk_ctlr %then
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
%endif

  { The geometry words DISK_INIT returns ([0] always 0, [1] the cylinder
    count reported), from 0. }
  win_$geometry_t = array[0..1] of pinteger;

  { The module's pointer to a volume (the block's +0x5C; the current
    request's, +0x60, is disk/disk.ins.pas's disk_$io_req_ptr_t). }
  win_$vol_ptr_t = ^disk_$volume_t;

%if win_ring_disk_ctlr %then
const
  { IOMAP's entries 64 and 65 (pbu/pbu.ins.pas), the Winchester's pages
    of the I/O map: the block header's page and the data page the DMA
    channels address. }
  win_iomap_first = 64;

var
  { The map symbols inside the map's WIN_ data segment (WIRED_DATA,
    0x80 bytes), defined in win/win.pas:
    - WIN_$CNT (+0x48), the statistics block (WIN_$GET_STATS copies it;
      here w_10 counts the controller's time-outs);
    - WIN_$STS (+0x7C), a longword nothing in the image addresses.
    Only WIN_'s own code addresses the block. }
  win_$cnt: extern win_$cnt_t;
  win_$sts: extern integer32;
%else
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
%endif

%if not win_ring_disk_ctlr %then
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
%endif

%if win_atbus_ctlr %then
{ Routine headings, in map order: the map's WIN_ code segment in
  WIRED_PROC (with `win_mailbox_ctlr' the WIN7_ routines first, from
  WIN7_$DINIT to WIN7_$INT; then WIN_$SPIN_DOWN, the module-local
  routines, whose headings are in their fragments, and WIN8_$DO_IO ..
  WIN8_$GET_STATS), WIN_ASM, and WIN_ in OS_INIT_PROC (WIN7_$CINIT with
  the part, then WIN_$CINIT).  WIN_SETUP_IOPB, WIN_SETUP_MAILBOX and
  WIN_SEND_COMMAND, map symbols without `$', are globals. }

%if win_mailbox_ctlr %then
{ WIN7_$DINIT - the unit initialization entry. }
function win7_$dinit(unit: integer; ctlr: pinteger;
                     var num_blocks: integer32;
                     out sec_per_track: pinteger; out num_heads: pinteger;
                     out pvlabel_info: win_$pvlabel_t;
                     out flags: pinteger): integer32;
  options(extern, val_param);

{ WIN_SETUP_IOPB - take a free command block and fill it in for an
  operation. }
procedure win_setup_iopb(in op: integer; in iova: integer32;
                         in unit: integer; in out ctlr: win7_$ctlr_t;
                         in drive: win7_$drive_t; in count: integer;
                         in req: disk_$io_req_ptr_t;
                         in param_8: univ integer32;
                         out status: status_$t);
  extern;

{ WIN_SETUP_MAILBOX - put the block being set up in the next outgoing
  mailbox. }
procedure win_setup_mailbox(in out ctlr: win7_$ctlr_t;
                            out start_cmd: integer32;
                            out status: status_$t);
  extern;

{ WIN_SEND_COMMAND - write a byte to the controller's command port. }
procedure win_send_command(in start: boolean; in cmd: integer;
                           in unit: integer; in out ctlr: win7_$ctlr_t;
                           out status: status_$t);
  extern;

{ WIN7_$GET_STATS - the statistics entry. }
procedure win7_$get_stats(cnum: pinteger; unit: pinteger;
                          out stats: win_$stats_t);
  options(extern, val_param);

{ WIN7_$DO_IO - the driver's I/O entry: format a track or the drive,
  or run a chain of read and write requests. }
procedure win7_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                      in param_3: univ integer32; out result: boolean);
  extern;

{ WIN7_$ERROR_QUE - the error queue entry: the failed blocks of the
  current process's requests on a drive. }
procedure win7_$error_que(in vol: disk_$volume_t; is_timeout: integer;
                          out result: boolean);
  options(extern, val_param);

{ WIN7_$INT - the controller's interrupt routine. }
function win7_$int(in dcte: win_$dcte_t): boolean;
  extern;
%endif

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
  win/m68k/win_asm.s): move a sector's header (16 words) and data (512
  words) to and from the controller's data port.  Each argument is a
  pointer, by address: the header's, the data's and the ports' for
  FILL; the ports', the header's and the data's for EMPTY. }
procedure win_$fill_ctl_buf(in hdr: univ_ptr; in data: univ_ptr;
                            in regs: win_$regs_ptr_t);
  extern;
procedure win_$empty_ctl_buf(in regs: win_$regs_ptr_t; in hdr: univ_ptr;
                             in data: univ_ptr);
  extern;

%if win_mailbox_ctlr %then
{ WIN7_$CINIT - a mailbox controller's initialization. }
function win7_$cinit(var dcte: win_$dcte_t): integer32;
  extern;

%endif
{ WIN_$CINIT - the Winchester controller's initialization. }
function win_$cinit(var dcte: win_$dcte_t): integer32;
  extern;
%else
{ WIN_$DO_IO - the driver's I/O entry: format a track, or run a chain of
  read and write requests. }
procedure win_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                     in param_3: univ integer32; out result: boolean);
  extern;

%if win_ring_disk_ctlr %then
{ DISK_INIT - bring a drive up and find its geometry. }
function disk_init(ctlr: pinteger; drive: pinteger;
                   var total_blocks: integer32;
                   var blocks_per_track: pinteger; var heads: pinteger;
                   out geometry: win_$geometry_t;
                   out drive_id: pinteger): integer32;
  options(extern, val_param);
%elseif not win_descriptor_ctlr %then
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
