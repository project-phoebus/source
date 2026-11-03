{ flp/flp.ins.pas - FLP_ (the floppy disk driver) constants, types,
  variables and routine headings, for the Domain Pascal tree.

  Holds only what the Pascal files use.  No customer insert file
  declares these: the layouts are the image's.  The module is
  flp/flp.pas.  Include base/base.ins.pas, ec/ec.ins.pas, ml/ml.ins.pas,
  io/io.ins.pas, time/time.ins.pas and disk/disk.ins.pas before it.
}

const
  { The driver's own "issue the command again" mark (no status-code
    database entry): EXCS returns it, FLP_DO_IO sets it and loops while
    it comes back. }
  flp_$retry = 16#0008FFFF;

  { 16#00080026, "unrecognized interrupt from disktape controller"
    (stcode.db.10.2): the AT bus form's FLP_$INT crashes with it when
    the controller does not get ready. }
  status_$unrecognized_interrupt = 16#00080026;

type
  { An unsigned byte (suma's form). }
  flp_$byte_t = [byte] 0..255;

  { The controller's registers, from the base the DCTE supplies
    (main_status and data_reg for its status and data, names that do not
    collide with the routines' status locals and SHAKE's data parameter
    inside `with' statements).  The main status register at 0x10 is read
    as a byte value (FLP_DO_IO) and its bits 6 and 7 tested as set
    members (FLP_$INT: member 7 is the byte's sign): two variants over
    the byte.  The word at 6 is tested whole (EXCS): a word set.
    `[device]': the status is polled in loops and the data register
    read and written once per byte (ref 3.15.3). }
%if floppy_atbus %then
  { The AT bus controller's ports (`floppy_atbus'), from the CSR page's
    base, with the same names for the main status and the data:
    - 0x02 dor: the digital output, the motor, DMA and reset bits
      (16#1C motor on, 16#0C motor off, 8 the controller held reset);
    - 0x04 main_status: the main status, read as a byte and its bits 7
      (RQM) and 6 (DIO) tested as set members; written 0 after a busy
      controller (the data rate);
    - 0x05 data_reg: the data register;
    - 0x06 reg_06: written 2 after a reset;
    - 0x07 dig_in: the digital input, bit 7 the disk change line, read
      as a byte and its bit 7 as a member; written 0 (the transfer
      rate).
    `[device]', as the other form; the bit sets are a byte each, as the
    ports are (a word would read the next port too).  No field is
    named like a routine's parameter or local, which the `with'
    statements would hide. }
  flp_$regs_t = [device] record
    case integer of
      1: (pad_00: array[0..1] of char;
          dor: flp_$byte_t;               { 0x02 }
          pad_03: char;
          main_status: flp_$byte_t;       { 0x04 }
          data_reg: flp_$byte_t;          { 0x05 }
          reg_06: flp_$byte_t;            { 0x06 }
          dig_in: flp_$byte_t);           { 0x07 }
      2: (pad_00b: array[0..3] of char;
          main_status_bits: [byte] set of 0..7;
                                          { 0x04: 7 RQM, 6 DIO }
          pad_05: char;
          pad_06: char;
          dig_in_bits: [byte] set of 0..7);
                                          { 0x07: 7 disk change }
  end;
%else
  flp_$regs_t = [device] record
    case integer of
      1: (pad_00: array[0..5] of char;
          w_06: set of 0..15;             { 0x06 }
          pad_08: array[8..15] of char;
          main_status: flp_$byte_t;       { 0x10: main status }
          pad_11: char;
          data_reg: flp_$byte_t;          { 0x12: data register }
          pad_13: char;
          control: flp_$byte_t);          { 0x14: board control }
      2: (pad_00b: array[0..15] of char;
          main_status_bits: set of 0..7); { 0x10: 7 RQM, 6 DIO }
  end;
%endif
  flp_$regs_ptr_t = ^flp_$regs_t;

  { An FDC result register, one byte per word: read as a word (EXCS,
    FLP_DO_IO) and its bits tested as members (EXCS: member 4 of a word
    set, in its low byte). }
  flp_$sreg_t = record
    case integer of
      1: (w: pinteger);                   { 0x00 }
      2: (bits: set of 0..15);            { 0x00 }
  end;

  { An FDC command or result block, one byte per word, 0-based (SHAKE
    walks it from its first word, the low byte at +1; EXCS reads words 0
    and 1).  Nine words, the longest block (READ/WRITE DATA, FLP_DO_IO's
    count). }
  flp_$words_t = array[0..8] of pinteger;

%if floppy_atbus %then
  { The controller's kind-3 DCTE (io/dctes.pas FLP_DCTE) as this form
    reads it: the controller number, the unit's request (IO_$MAP_CSR's
    and IO_$ACQUIRE's; the ports' address its CSR page's) and the high
    word of the disk error queue longword at 0x48, the ML lock of
    FLP_DO_IO and DISK_$REGISTER's `flags'. }
  flp_$dcte_t = record
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
  flp_$dcte_ptr_t = ^flp_$dcte_t;

  { A pointer to a page's last longword (FLP_DO_IO's read-back compares
    the written page's and the overrun page's). }
  flp_$long_ptr_t = ^integer32;

  { One controller's slot: the DCTE FLP_$CINIT was given and its ports. }
  flp_$ctlr_entry_t = record
    dcte: flp_$dcte_ptr_t;                { 0x00 }
    hw_addr: flp_$regs_ptr_t;             { 0x04 }
  end;

  { FLP_$OVERRUN_REC, 0x50 bytes: the count of read-backs at 0x04 (one
    each FLP_DO_IO), and at 0x10 the request a write's read-back runs,
    the written request's copy made a read into the overrun page. }
  flp_$overrun_rec_t = record
    unused_00: integer32;                 { 0x00 }
    count: integer32;                     { 0x04 }
    unused_08: integer32;                 { 0x08 }
    unused_0c: integer32;                 { 0x0C }
    req: disk_$io_req_t;                  { 0x10 }
  end;
%else
  { One controller's slot: the DCTE FLP_$CINIT was given and its register
    base. }
  flp_$ctlr_entry_t = record
    dcte: dcte_ptr_t;                     { 0x00 }
    hw_addr: flp_$regs_ptr_t;             { 0x04 }
  end;
%endif

  { One sector's ID in the FORMAT TRACK table (flp_format_track): C, H,
    R, N.  The names are the FDC's fields (cylinder, head, record, size
    code). }
  flp_$id_entry_t = record
    c: flp_$byte_t;                       { 0x00 }
    h: flp_$byte_t;                       { 0x01 }
    r: flp_$byte_t;                       { 0x02 }
    n: flp_$byte_t;                       { 0x03 }
  end;

  { The 10-byte record FLP_$DINIT fills in: copied as two longwords and a
    word, then the word at 6 stored. }
  flp_$pvlabel_info_t = record
    l_00: integer32;                      { 0x00 }
    w_04: pinteger;                       { 0x04 }
    w_06: pinteger;                       { 0x06 }
    w_08: pinteger;                       { 0x08 }
  end;

var
  { FLP_$EC and FLP_$SREGS, the two map symbols inside FLP_'s data
    segment (.DATA), defined in flp/flp.pas: the eventcount FLP_$INT
    advances and EXCS waits on, and the result registers FLP_$INT
    collects (0-based: FLP_$INT's pointer starts at the array). }
  flp_$ec: extern ec_$eventcount_t;
  flp_$sregs: extern array[0..3] of flp_$sreg_t;
%if floppy_atbus %then

  { The AT bus form's other map symbols in the block, defined in
    flp/flp.pas: FLP_$OVERRUN_REC (above), FLP_$OVRRUN_CTR (the count of
    read-backs that did not match), FLP_$USED (a drive used since the
    motor's last check) and FLP_$MOTOR_ON. }
  flp_$overrun_rec: extern flp_$overrun_rec_t;
  flp_$ovrrun_ctr: extern integer32;
  flp_$used: extern boolean;
  flp_$motor_on: extern boolean;

  { FLP_PAGE and FLP_OVRRUN_PAGE (map symbols, in the BUFFER_PAGES
    region): the pages a write's data and its read-back are mapped at. }
  flp_page: extern array[0..1023] of char;
  flp_ovrrun_page: extern array[0..1023] of char;
%endif

{ Routine headings, in map order: FLP_'s WIRED_PROC segment, then its
  .TEXT segment.  The map symbols without `$' (FLP_DO_IO, EXCS, SHAKE)
  are globals too.  The bodies repeat the full heading (ref 7.3.4,
  Method 2). }

{ FLP_$INT (flp/int.pas), the interrupt routine, entered through
  FLP_DCTE's disk_do_io field. }
function flp_$int(in dcte: dcte_t): boolean;
  extern;

{ FLP_$REVALIDATE - clear the disk-change flag of a volume's drive. }
procedure flp_$revalidate(in vol: disk_$volume_t);
  extern;

%if floppy_atbus %then
{ FLP_$SHUT_DOWN_MOTOR - switch the drives' motor off. }
procedure flp_$shut_down_motor;
  extern;

{ SET_FLP_TIMER (a map symbol without `$'): queue the motor's callback
  after a time. }
procedure set_flp_timer(in when: time_$clock_t);
  extern;

{ FLP_$TURN_MOTOR_ON - switch the drives' motor on, and wait for it. }
procedure flp_$turn_motor_on;
  extern;

{ FLP_$MOTOR_CALLBACK - the time queue's callback: the motor off when
  no drive was used since the last call. }
procedure flp_$motor_callback(in elem: time_$queue_elem_ptr_t);
  extern;

{ FLP_DO_IO (flp/flp_do_io.pas): param_3 is not read; locked, true for
  the read-back FLP_DO_IO runs itself, under the lock already held. }
procedure flp_do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                    in param_3: univ integer32; locked: boolean;
                    out result: boolean);
  options(extern, val_param);
%else
{ FLP_DO_IO (flp/flp_do_io.pas): param_3 and zero are not read. }
procedure flp_do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                    in param_3: univ integer32; zero: integer;
                    out result: boolean);
  options(extern, val_param);
%endif

{ FLP_$DO_IO - the driver's I/O entry. }
procedure flp_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                     in param_3: univ integer32; out result: boolean);
  extern;

{ FLP_$CINIT - initialize a floppy controller. }
%if floppy_atbus %then
function flp_$cinit(var dcte: flp_$dcte_t): integer32;
  extern;
%else
function flp_$cinit(var dcte: dcte_t): integer32;
  extern;
%endif

{ FLP_$DINIT (flp/dinit.pas): jump table entry 2 (+0x08), the unit
  initialization. }
function flp_$dinit(unit: pinteger; ctlr: pinteger;
                    var num_blocks: integer32;
                    out sec_per_track: pinteger; out num_heads: pinteger;
                    out pvlabel_info: flp_$pvlabel_info_t;
                    out flags: pinteger): integer32;
  options(extern, val_param);

{ FLP_$SHUTDOWN - mark a drive inactive and count the active ones. }
function flp_$shutdown(ctlr: pinteger; unit: pinteger): integer;
  options(extern, val_param);

{ EXCS (flp/excs.pas): execute an FDC command. }
function excs(var cmd: univ flp_$words_t; in count: integer;
              in vol: disk_$volume_t): integer32;
  extern;

{ SHAKE (flp/shake.pas): move a block between memory and the FDC's data
  register; `univ': the callers pass blocks and single words. }
function shake(var data: univ flp_$words_t; in count: integer;
               in dir: integer): integer32;
  extern;
