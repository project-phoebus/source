{ ct/ct.ins.pas - CT (cartridge tape) routine headings, constants and
  types, for the Domain Pascal tree.

  The CT module (ct/ct.pas): with `ct_driver' (base/config.ins.pas, the
  SAU5..SAU9) the driver; on the SAU2..SAU4 only the empty CT_$RELEASE.
  The driver's declarations below are the QIC-02 driver's (`ct_qic02'),
  the statuses and operations shared with the SCSI tape driver
  (`ct_scsi'), whose own come last.

  Include base/base.ins.pas before it (and, for CT_$CINIT's and
  CT_$INT's headings, io/io.ins.pas; for the SCSI tape driver's,
  scsi/scsi.ins.pas).
}

{ CT_$RELEASE - release the cartridge tape unit. }
procedure ct_$release(in unit: integer; in mode: boolean;
                      out status_ret: status_$t); extern;

%if ct_driver %then
{ ---- The cartridge tape driver (`ct_driver', base/config.ins.pas: the
  SAU5..SAU9).  As the SAU5's QIC-02 driver has it; the SCSI tape
  driver's own declarations follow at the end, and the SAU6..SAU8's CT
  code differs (ct/ct.pas). ---- }

const
  { The cartridge-tape statuses (module 16#28, stcode.db.10.2's "OS /
    cartridge tape manager"; its texts in the comments).  The names
    follow the texts (shortened: "eot" end of tape, "bot" load point,
    "diag" diagnostic, "dma parity" memory parity error during dma).
    The 16#28FFFx codes are warnings: their code word is negative. }
  status_$ct_tape_in_write_mode = 16#0028FFFA;
  status_$ct_tape_in_read_mode = 16#0028FFFB;
  status_$ct_tape_at_load_point = 16#0028FFFD;    { tape at load point }
  status_$ct_tape_power_on_reset = 16#0028FFFF;   { tape power on/reset }
  status_$ct_invalid_unit_number = 16#00280001;   { invalid ct unit number }
  status_$ct_unit_not_acquired = 16#00280002;     { unit not acquired }
  status_$ct_unit_already_acquired = 16#00280003; { unit already acquired }
  status_$ct_unit_in_use = 16#00280004;           { unit in use }
  status_$ct_no_tape_controller = 16#00280005;
  status_$ct_bad_buffer_alignment = 16#00280007;  { bad buffer alignment }
  status_$ct_invalid_buffer_address = 16#00280008; { invalid buffer address }
  status_$ct_unrecognized_action_type = 16#00280009;
  status_$ct_invalid_operation_count = 16#0028000A; { invalid operation count }
  status_$ct_quit_waiting_for_io = 16#0028000D;   { quit waiting for i/o }
  status_$ct_timeout_waiting_for_io = 16#0028000E; { timeout waiting for i/o }
  status_$ct_no_cartridge_in_drive = 16#00280010; { no cartridge in drive }
  status_$ct_drive_does_not_exist = 16#00280011;  { drive does not exist }
  status_$ct_tape_write_protected = 16#00280012;  { tape is write protected }
  status_$ct_end_of_tape = 16#00280013;           { end of tape }
  status_$ct_read_write_abort = 16#00280014;      { read/write abort }
  status_$ct_read_block_error = 16#00280015;      { read block error }
  status_$ct_read_filler_error = 16#00280016;     { read filler error }
  status_$ct_read_no_data = 16#00280017;          { read no data }
  status_$ct_read_no_data_and_eot = 16#00280018;
  status_$ct_read_no_data_and_bot = 16#00280019;
  status_$ct_illegal_drive_command = 16#0028001B; { illegal drive command }
  status_$ct_marginal_block_detected = 16#0028001C; { marginal block detected }
  status_$ct_unrecognized_drive_status = 16#0028001D;
  status_$ct_dma_not_at_end_of_range = 16#0028001E; { dma not at end of range }
  status_$ct_dma_underrun_overrun = 16#0028001F;  { dma underrun/overrun }
  status_$ct_dma_parity_error = 16#00280020;
  status_$ct_illegal_controller_command = 16#00280021;
  status_$ct_controller_timeout = 16#00280022;    { controller timeout }
  status_$ct_controller_diag_failed = 16#00280023;
  status_$ct_unrecognized_controller_status = 16#00280024;
  status_$ct_operation_in_progress = 16#00280025;

  { The controller's command codes, written to its command register.  What
    they mean: read (26) and write (24) from CT_$READ and CT_$WRITE;
    rewind (21) from TAPE_$BOOT's message "bad rewind" for CT_$CONTROL's
    operation 8; the file spacing pair (29, 30) from CT_WAIT, which takes
    "filemark detected" as their success, and TAPE_$BOOT's "bad space
    request" for operation 3; write filemark (25), the one operation that
    needs the tape where writing may begin; reset (31), the command
    RESET_DRIVE repeats and CT_$RELEASE and CT_$ACQUIRE give to end an
    operation in progress.  Load (20, CT_$ACQUIRE's first command,
    answered "tape at load point"), erase (22), retension (23) and the
    block spacing pair (27, 28) are guesses from the sequence and from
    the direction each sets. }
%if ct_atbus_qic02 %then
  { With the AT bus adapter (`ct_atbus_qic02') the commands are the
    QIC-02 interface's command bytes, which the driver writes to the
    data port: rewind, erase, retension, write, write filemark, read,
    the read status command, and the block and file spacing pairs
    (CT_$CONTROL's operations 1..4). }
  ct_cmd_rewind = 16#21;
  ct_cmd_erase = 16#22;
  ct_cmd_retension = 16#24;
  ct_cmd_write = 16#40;
  ct_cmd_write_filemark = 16#60;
  ct_cmd_read = 16#80;
  ct_cmd_space_fwd = 16#81;
  ct_cmd_space_rev = 16#89;
  ct_cmd_file_fwd = 16#A0;
  ct_cmd_file_rev = 16#A8;
  ct_cmd_read_status = 16#C0;

  { The adapter's control port values: the reset, the request (the
    command or the status byte's handshake), the interrupt enable, the
    interrupt and DMA enable. }
  ct_ctl_reset = 16#80;
  ct_ctl_request = 16#40;
  ct_ctl_int_enable = 16#20;
  ct_ctl_dma_enable = 16#30;

  { CT_$CINIT's probe: the status the adapter shows after its reset,
    then the one it settles to. }
  ct_probe_reset = 16#F7;
  ct_probe_ready = 16#57;
%else
  ct_cmd_load = 20;
  ct_cmd_rewind = 21;
  ct_cmd_erase = 22;
  ct_cmd_retension = 23;
  ct_cmd_write = 24;
  ct_cmd_write_filemark = 25;
  ct_cmd_read = 26;
  ct_cmd_space_fwd = 27;
  ct_cmd_space_rev = 28;
  ct_cmd_file_fwd = 29;
  ct_cmd_file_rev = 30;
  ct_cmd_reset = 31;
%endif

  { The transfer state (ct_state): none, a read
    under way, a write under way.  CT_$ACQUIRE's and CT_$CONTROL's case
    labels. }
  ct_state_none = 0;
  ct_state_read = 1;
  ct_state_write = 2;

  { DO_CTL_CMD's count that asks for one block without the controller's
    lock (RESET_DRIVE's and CT_$ACQUIRE's load). }
  ct_count_unlocked = 999;

  { CT_$CONTROL's operations, its case labels, and the command each
    issues. }
  ct_$op_load = 0;                        { ct_cmd_load }
  ct_$op_space_fwd = 1;                   { ct_cmd_space_fwd, counted }
  ct_$op_space_rev = 2;                   { ct_cmd_space_rev, counted }
  ct_$op_file_fwd = 3;                    { ct_cmd_file_fwd, counted }
  ct_$op_file_rev = 4;                    { ct_cmd_file_rev, counted }
  ct_$op_write_filemark = 5;              { ct_cmd_write_filemark, counted }
  ct_$op_erase = 6;                       { ct_cmd_erase }
  ct_$op_retension = 7;                   { ct_cmd_retension }
  ct_$op_rewind = 8;                      { ct_cmd_rewind }
  ct_$op_reset = 9;                       { ct_cmd_reset }

  { CT_$DIAG's modes, its case labels: the drive
    status word, the controller's first 256 register words, the two
    counters the interrupt totals. }
  ct_$diag_drive_status = 0;
  ct_$diag_registers = 1;
  ct_$diag_counts = 2;

  { The word CT_$CINIT writes to probe the controller's window (TESTPAGE
    kind 3); WIN_$CINIT's with the descriptor-list controller is the
    same (win/win.ins.pas). }
  ct_probe_word = 16#3D05;

type
  { The buffers of a transfer, one address per 512-byte block (CT_$READ,
    CT_$WRITE: up to 512 blocks), and the lists of wired pages the
    driver keeps. }
  ct_$page_list_t = array[1..512] of integer32;
  ct_$page_flags_t = array[1..512] of boolean;

  { CT_$DIAG's buffer: words. }
  ct_$diag_buf_t = array[1..256] of integer;

  { A transfer descriptor of the controller's window, 12 bytes: the
    block's physical address, and a word the driver clears (only the
    first descriptor's, ct/transfer.pas). }
  ct_$desc_t = record
    addr: integer32;                      { 0x00 }
    unused_04: integer;                   { 0x04 }
    w06: integer;                         { 0x06 }
    unused_08: integer32;                 { 0x08 }
  end;

  { The controller's window (the DCTE's disk_dinit address), as the
    driver addresses it.  A device: every access is a real access, and
    constants are stored with moves.  The second variant is the first
    256 words CT_$DIAG copies, and the word after them. }
  ct_$regs_t = [device] record
    case integer of
      1: (go: [byte] 0..255;              { 0x00: 1 starts a command }
          cmd: [byte] 0..255;             { 0x01: the command code }
          cstat: integer;                 { 0x02: the controller's status }
          unused_04: integer;             { 0x04 }
          count: [byte] 0..255;           { 0x06: blocks to go }
          ctl_07: [byte] 0..255;          { 0x07: cleared by CT_$CINIT }
          w08: integer;                   { 0x08 }
          w0a: integer;                   { 0x0A }
          unused_0c: array[1..15] of integer; { 0x0C }
          dstat: integer;                 { 0x2A: the drive's status }
          count_2c: integer;              { 0x2C }
          count_2e: integer;              { 0x2E }
          unused_30: array[1..42] of integer; { 0x30 }
          desc: array[1..32] of ct_$desc_t; { 0x84 }
          unused_204: array[1..126] of integer; { 0x204 }
          config: integer);               { 0x300: the probe word }
      2: (words: array[1..256] of integer; { 0x00 }
          words_end: integer);            { 0x200 }
  end;
  ct_$regs_ptr_t = ^ct_$regs_t;

%if ct_atbus_qic02 %then
  { The AT bus adapter's status, the word at its first port read whole:
    bits 7..0 are the status port's (the second byte). }
  ct_$atbus_stat_t = packed record
    data: 0..255;                         { bits 15..8: the data port }
    unused_7: boolean;                    { bit 7 }
    not_ready: boolean;                   { bit 6 }
    no_exception: boolean;                { bit 5 }
    dma_done: boolean;                    { bit 4 }
    unused_3_0: 0..15;                    { bits 3..0 }
  end;

  { The AT bus adapter's ports (the DCTE's request's CSR page): the data
    port (the command byte written, a status byte read), the control
    port (read: the status), the DMA go and DMA reset ports. }
  ct_$atbus_regs_t = [device] record
    case integer of
      1: (data: [byte] 0..255;            { 0x00 }
          ctl: [byte] 0..255;             { 0x01 }
          dma_go: [byte] 0..255;          { 0x02 }
          dma_reset: [byte] 0..255);      { 0x03 }
      2: (stat: ct_$atbus_stat_t;         { 0x00 }
          unused_02: integer);            { 0x02 }
      3: (words: array[1..2] of integer); { 0x00 }
  end;
  ct_$atbus_regs_ptr_t = ^ct_$atbus_regs_t;

  { A word of the drive's status bytes, as the driver stores them one by
    one. }
  ct_$status_bytes_t = record
    case integer of
      1: (all: integer);
      2: (hi: [byte] 0..255;              { 0x00 }
          lo: [byte] 0..255);             { 0x01 }
  end;
%endif

  { A status word of the controller or the drive, as the driver keeps
    it: tested by bits and as a whole. }
  ct_$stat_t = record
    case integer of
      1: (all: integer);
      2: (bits: set of 0..15);
  end;

  { An entry of the driver's table that maps the drive's status word to a
    status: the bits to look at, their value, the status. }
  ct_$status_map_t = record
    mask: integer;                        { 0x00 }
    value: integer;                       { 0x02 }
    status: integer32;                    { 0x04 }
  end;

{ The members of the controller's status word (ct_cstat) the driver
  tests, after the status each gives. }
const
  ct_cst_diag_failed = 1;                 { controller diagnostic failed }
  ct_cst_timeout = 2;                     { controller timeout }
  ct_cst_illegal_cmd = 3;                 { illegal controller command }
  ct_cst_dma_parity = 5;                  { memory parity error during dma }
  ct_cst_dma_overrun = 6;                 { dma underrun/overrun }
  ct_cst_dma_range = 7;                   { dma not at end of range }

var
  { The markers of the module's wired range (map symbols):
    CT_$PROC_START (the module's first byte), CT_$PROC_END
    (ct/m68k/end_addr.s), CT_$DATA_START (the data block's first byte)
    and CT_$DATA_END (the next segment's); only their addresses are
    used (CT_$ACQUIRE's MST_$WIRE_AREA). }
  ct_$proc_start: extern char;
  ct_$proc_end: extern char;
  ct_$data_start: extern char;
  ct_$data_end: extern char;

{ ---- The globals' headings, in map order.  The default convention
  (every argument by address). ---- }

{ CT_WAIT, RESET_DRIVE and DO_CTL_CMD (map symbols without `$'): global
  routines of the default convention.  Each loads A5 with the data
  block, as the globals do (the module-local routines use their
  caller's), and every caller passes CT_WAIT's and DO_CTL_CMD's
  arguments by address, constant cells but for CT_$WAIT's time-out and
  CT_$CONTROL's count: `in'.  The results are statuses, which the
  callers store or test: integer32. }

{ CT_WAIT - wait for the controller to end the outstanding command. }
function ct_wait(in timeout: integer32; in allow_quit: boolean): integer32;
  extern;

{ RESET_DRIVE - reset the tape controller, or crash. }
procedure reset_drive; extern;

{ DO_CTL_CMD - start a control command on the tape controller. }
function do_ctl_cmd(in ctl_cmd: integer; in ctl_count: integer): integer32;
  extern;

{ CT_$CINIT and CT_$INT take io/io.ins.pas's dcte_t, and only IO_'s
  DCTES block names them: their headings are io/io.ins.pas's (under
  ct_driver), which ct/ct.pas includes. }

const
  status_$ct_tape_not_at_load_point = 16#0028FFFC;
  status_$ct_filemark_detected = 16#0028001A;     { filemark detected }

{ CT_$ACQUIRE - acquire the cartridge tape unit for the current
  process. }
procedure ct_$acquire(in unit: integer; out status: status_$t); extern;

{ CT_$CONTROL - perform a tape motion or control operation. }
procedure ct_$control(in unit: integer; in op: integer; in count: integer;
                      out status: status_$t);
  extern;

{ CT_$DIAG - return diagnostic information about the tape controller. }
procedure ct_$diag(in unit: integer; in mode: integer;
                   out buf: univ ct_$diag_buf_t; in buf_len: integer;
                   out ret_len: integer; out status: status_$t);
  extern;

{ CT_$READ - read blocks from the cartridge tape. }
procedure ct_$read(in unit: integer; in pages: univ ct_$page_list_t;
                   in npages: integer; out nread: integer;
                   out status: status_$t);
  extern;

{ CT_$WAIT - wait for the outstanding tape operation to end. }
procedure ct_$wait(in unit: integer; in timeout: integer;
                   out count: integer; out status: status_$t);
  extern;

{ CT_$WRITE - write blocks to the cartridge tape. }
procedure ct_$write(in unit: integer; in pages: univ ct_$page_list_t;
                    in npages: integer; out nwritten: integer;
                    out status: status_$t);
  extern;

%endif

%if ct_scsi %then
{ ---- The SCSI tape driver (`ct_scsi', base/config.ins.pas: the SAU9's
  driver, the SAU7's beside the QIC-02 one).  It drives a SCSI tape
  drive, target 0 of bus 0, through the SCSI_ driver (scsi/scsi.ins.pas,
  which ct/ct.pas includes).  The statuses above are its statuses too;
  CT_$CONTROL's operations and CT_$DIAG's modes keep their numbers. ---- }

const
  status_$ct_unit_not_ready = 16#0028000B;        { unit not ready }

  { Whether the drive answers (ct_scsi_state): not known yet, set up,
    not on the bus.  CT_$ACQUIRE sets it; the other globals act only on
    a drive that is set up. }
  ct_scsi_unknown = 0;
  ct_scsi_present = 1;
  ct_scsi_absent = 2;

  { The SCSI commands the driver sends (the SCSI-1 sequential-access
    command set; REQUEST BLOCK ADDRESS, 16#02, is vendor-unique: it
    answers 3 bytes, the block the tape is at, 1 at the load point). }
  ct_scsi_op_rewind = 16#01;
  ct_scsi_op_request_block_address = 16#02;
  ct_scsi_op_request_sense = 16#03;
  ct_scsi_op_read = 16#08;
  ct_scsi_op_write = 16#0A;
  ct_scsi_op_write_filemarks = 16#10;
  ct_scsi_op_space = 16#11;
  ct_scsi_op_mode_select = 16#15;
  ct_scsi_op_erase = 16#19;
  ct_scsi_op_mode_sense = 16#1A;
  ct_scsi_op_load_unload = 16#1B;
  ct_scsi_op_send_diagnostic = 16#1D;

  { Byte 1's low bits: SPACE's code (blocks, filemarks), READ's and
    WRITE's fixed-length bit, ERASE's long bit; LOAD/UNLOAD's byte 4
    (re-tension) and SEND DIAGNOSTIC's byte 1 (self-test). }
  ct_scsi_space_blocks = 0;
  ct_scsi_space_filemarks = 1;
  ct_scsi_fixed = 1;
  ct_scsi_erase_long = 1;
  ct_scsi_retension = 2;
  ct_scsi_self_test = 4;

  { ct_scsi_control's operations beyond CT_$CONTROL's (ct_$op_space_fwd
    .. ct_$op_reset, 1..9): its case labels. }
  ct_op_block_address = 10;               { REQUEST BLOCK ADDRESS }
  ct_op_mode_sense = 11;                  { MODE SENSE, 4 bytes }
  ct_op_mode_select = 12;                 { MODE SELECT, 4 bytes }
  ct_op_self_test = 13;                   { SEND DIAGNOSTIC }

  { The time-outs SCSI_WAIT passes to SCSI_$WAIT, in milliseconds: a
    command's, a transfer's, and CT_$WAIT's for a negative time-out. }
  ct_scsi_timeout = 10000;
  ct_scsi_xfer_timeout = 90000;
  ct_scsi_long_timeout = 8000000;

  { REQUEST SENSE's allocation length, the length the driver gives
    SCSI_$DO_COMMAND for its answer, and the length of the sense and
    mode answers the driver wires (ct_sense and ct_mode, adjacent). }
  ct_sense_alloc = 14;
  ct_sense_len = 42;
  ct_scsi_wired_len = 50;

  { The MODE SELECT parameter list's header the driver sends after a
    power-on reset: buffered mode 1. }
  ct_mode_buffered = 16#1000;

  { The largest count of a counted CT_$CONTROL operation. }
  ct_max_op_count = 32;

  { The sense keys ct_request_sense tells apart (the SCSI standard's). }
  ct_key_no_sense = 0;
  ct_key_recovered_error = 1;
  ct_key_not_ready = 2;
  ct_key_medium_error = 3;
  ct_key_hardware_error = 4;
  ct_key_illegal_request = 5;
  ct_key_unit_attention = 6;
  ct_key_data_protect = 7;
  ct_key_blank_check = 8;
  ct_key_aborted_command = 11;
  ct_key_volume_overflow = 13;

type
  { The REQUEST SENSE answer as the driver reads it, 42 bytes: the valid
    bit, the filemark and end-of-medium bits, the sense key, the
    information bytes 3..6 (a byte-aligned longword at byte 3), and the
    word at byte 22 CT_$DIAG returns. }
  ct_sense_t = record
    case integer of
      1: (f: packed record
            valid: boolean;               { 0x00, bit 7 }
            err_class: 0..7;              { 0x00, bits 6..4 }
            err_code: 0..15;              { 0x00, bits 3..0 }
            segment: 0..255;              { 0x01 }
            filemark: boolean;            { 0x02, bit 7 }
            eom: boolean;                 { 0x02, bit 6 }
            ili: boolean;                 { 0x02, bit 5 }
            unused_2_4: boolean;          { 0x02, bit 4 }
            key: 0..15;                   { 0x02, bits 3..0 }
          end);
      2: (unused_00: array[0..2] of char; { 0x00 }
          info: [aligned(0)] integer32);  { 0x03 }
      3: (w: array[0..20] of integer);    { 0x00: w[11] at byte 22 }
  end;

  { The answers of MODE SENSE (its 4-byte header) and REQUEST BLOCK
    ADDRESS (3 bytes at byte 1), and the MODE SELECT parameter list's
    header (at byte 4), 8 bytes.  Word aligned: the block has it right
    after the 42-byte sense answer, 2 bytes past a longword boundary. }
  ct_mode_t = record
    case integer of
      1: (f: packed record
            data_len: 0..255;             { 0x00 }
            medium: 0..255;               { 0x01 }
            wp: boolean;                  { 0x02, bit 7: write protected }
            dev_rest: 0..127;             { 0x02, bits 6..0 }
            bd_len: 0..255;               { 0x03 }
          end);
      2: (g: packed record                { the block address, 24 bits }
            unused_0: 0..255;             { 0x00 }
            addr: 0..16#FFFFFF;           { 0x01 }
          end);
      3: (h: packed record                { its low 20 bits }
            unused_0: 0..4095;            { 0x00 and 0x01, bits 7..4 }
            addr: 0..16#FFFFF;            { 0x01, bits 3..0 }
          end);
      4: (b: array[0..7] of char);        { 0x00 }
      5: (hdr: [aligned(1)] integer32;    { 0x00 }
          select: [aligned(1)] integer32); { 0x04 }
  end;

  { A longword and its low 24 bits (ct_to_24, ct_from_24). }
  ct_int24_t = record
    case integer of
      1: (all: integer32);
      2: (f: packed record
            hi: 0..255;
            lo: 0..16#FFFFFF;
          end);
  end;

{ SCSI_WAIT - wait for the drive's command to end, and turn its result
  into a status.  The map's name (no `$'): a global of the default
  convention, every argument by address (constant cells but for
  CT_$WAIT's time-out); it loads A5 with the data block, as the globals
  do.  allow_quit is not read: SCSI_$WAIT is told not to allow a quit. }
function scsi_wait(in timeout: integer32; in allow_quit: boolean): integer32;
  extern;
%endif
