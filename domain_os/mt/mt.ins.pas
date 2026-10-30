{ mt/mt.ins.pas - MT (magnetic tape) routine headings, for the Domain
  Pascal tree.

  The magnetic tape driver is configured out of the SR10.2 SAU2 kernel;
  what is left is the empty MT_$RELEASE (the MT module, mt/mt.pas).  The
  SAU3..SAU6 have the driver (`mt_driver', base/config.ins.pas), whose
  declarations follow under that part.  Apollo's customer insert files
  of SR10.2 declare nothing of MT.  Include base/base.ins.pas before it,
  and with the driver io/io.ins.pas (TESTPAGE, MT_$PRESENT).
}

{ MT_$RELEASE - release the magnetic tape. }
procedure mt_$release(in unit: integer; in mode: integer;
                      out status_ret: status_$t); extern;

%if mt_driver %then
const
  { The TESTPAGE kind of MT_$PRESENT's probe of the controller's page:
    2, a byte written (io/m68k/probe.s). }
  mt_probe_kind = 2;

  { The magnetic tape controller's PBU unit number, the first argument
    of the PBU_ calls (one constant cell for the module). }
  mt_pbu_unit = 3;

  { The mode mt_$release_unit gives PBU_$RELEASE_INT, which compares
    its mode with 2 (public). }
  mt_release_mode = 3;

  { What mt_$set_iomap adds to a physical page number for its I/O map
    entry (the long_iomap part; sm/sm.ins.pas's sm_iomap_bias). }
  mt_iomap_bias = 16#48000;

  { The value mt_$shutdown writes to the controller's control register. }
  mt_ctl_shutdown = 16#30;

  { The members of MT_$SCB's flag set (+0x32) the translated routines
    use: 15, the driver's pages are wired; 14, the controller's PBU
    device is enabled (MT_$PRESENT answers true without a probe then).
    13, the busy flag the hand-written MT_$MT_BUSY tests and sets, which
    MT_$WAIT clears after a timeout. }
  mt_scb_wired = 15;
  mt_scb_enabled = 14;
  mt_scb_busy = 13;

  { MT_$WAIT's timeout when the caller gives 0: an hour, in
    milliseconds. }
  mt_default_timeout = 3600000;

  { MT_$ACQUIRE's constants: the members of the tape status it tests
    after rewinding (6, the unit online; 5, at the load point), the
    wait's timeout, the tries of the reset's wait, the values the reset
    writes to the controller's register and to MT_$SCB's control word,
    the MT page's pages, and the operation of the first request after a
    reset (0; what the controller does with it is not seen). }
  mt_status_online = 6;
  mt_status_load_point = 5;
  mt_acquire_timeout = 10;
  mt_reset_tries = 10000;
  mt_ctl_reset = 16#30;
  mt_ctl_word_reset = 16#11FF;
  mt_page_pages = 3;
  mt_op_setup = 0;

  { The magnetic tape statuses mt_$queue_request returns (module 16#22,
    stcode.db.10.2's magtape texts in the comments).  The names
    follow the texts. }
  status_$mt_invalid_unit_number = 16#00220001;  { invalid mt unit number }
  status_$mt_invalid_mode = 16#00220002;         { invalid mode field }
  status_$mt_invalid_parameter = 16#00220004;    { invalid parameter }
  status_$mt_no_pna_board = 16#00220005;
    { no PNA board installed in system }
  status_$mt_not_connected = 16#00220006;
    { magtape unit is not connected }
  status_$mt_unit_in_use = 16#0022000A;         { magtape unit in use }
  status_$mt_already_acquired = 16#0022000C;    { magtape already acquired }
  status_$mt_drive_hung = 16#00220011;          { tape drive is hung }
  { 16#220013, config page in use - internal error, with its fail bit
    (16#80220013), as MT_$ACQUIRE stores it in one longword. }
  status_$mt_config_page_in_use_fail = -16#7FDDFFED;
  status_$mt_not_at_load_point = 16#0022FFFE;
    { warning: tape not at load-point }
  status_$mt_offline = 16#0022FFFF;             { warning: tape unit is offline }
  status_$mt_invalid_buffer_length = 16#00220003; { invalid buffer length }
  status_$mt_not_acquired = 16#00220007;         { magtape not acquired }
  status_$mt_too_many_operations = 16#0022000E;
    { too many outstanding operations }
  status_$mt_invalid_buffer_address = 16#0022000F; { invalid buffer address }
  status_$mt_op_before_wait = 16#00220016;
    { operation attempted before waiting }
  status_$mt_go_not_in_batch_mode = 16#00220018;
  status_$mt_invalid_option = 16#0022000D;       { invalid option }
  status_$mt_invalid_count = 16#00220010;
    { invalid count for erase or space operation }
  status_$mt_buffer_already_wired = 16#00220021;  { buffer already wired }
  status_$mt_header_or_buffer_misaligned = 16#00220019;
    { header or buffer misalignment on chained r/w }
  status_$mt_header_not_on_header_page = 16#0022001C;
    { header buffer not on header page }
  status_$mt_wait_before_go = 16#00220017;
    { wait attempted before go issued }
  status_$mt_quit_in_wait = 16#0022001A;
    { user quit while in mt_$wait }
  status_$mt_wait_timeout = 16#0022001B;
    { timeout during wait or release }
  status_$mt_info_too_small = 16#0022001E;
    { info array (passed to mt_$wait) too small }
  status_$mt_will_not_fit_thru_hatch = 16#00220009;
    { unit will not fit thru 25" hatch }
    { go command issued while not in batch mode }

  { 16#1E0019 "page already wired", which mt_$queue_request takes as
    success from PBU_$SAVE_PPN: pbu/pbu.ins.pas's
    status_$pbu_page_already_wired. }

  { The operations mt_$queue_request is given (the request block's op):
    16#2C a read and 16#30 a write, which carry a buffer (MT_$READ,
    MT_$CHAIN_READ; MT_$WRITE, MT_$CHAIN_WRITE); 16#FE only checks the
    unit and its owner after retiring the finished requests (MT_$WAIT,
    MT_$RELEASE, MT_$SET_MODE, MT_$WIRE, the chained routines before
    their transfer); 16#FD the same check without retiring them; 16#FF
    starts a batch of queued requests.  Other operations (the control,
    erase and space requests) are queued with a count and no buffer. }
  mt_op_read = 16#2C;
  mt_op_write = 16#30;
  mt_op_check_only = 16#FD;
  mt_op_check = 16#FE;
  mt_op_go = 16#FF;

  { MT_$ERASE's operations: 16#4C with a count above 0 (its option 0),
    16#50 with a count of 0 (option 1).  What each operation erases is
    the controller's command, not seen in the driver. }
  mt_op_erase = 16#4C;
  mt_op_erase_long = 16#50;

  { MT_$ERASE's options, as above. }
  mt_erase_count = 0;
  mt_erase_long = 1;

  { MT_$SPACE's modes and operations: mode 0 queues 16#48, mode 1
    16#70, mode 2 16#44 for a count of 1 and 16#94 for another count.
    What the controller's commands do the driver does not show. }
  mt_space_mode_0 = 0;
  mt_space_mode_1 = 1;
  mt_space_mode_2 = 2;
  mt_op_space_mode_0 = 16#48;
  mt_op_space_mode_1 = 16#70;
  mt_op_space_mode_2_one = 16#44;
  mt_op_space_mode_2 = 16#94;

  { MT_$CONTROL's functions 0..8 and the operations they queue: 0 16#20,
    1 16#28 (MT_$ACQUIRE's), 2 16#1C, 3 16#40, 4 16#04, 5 16#38, 6
    16#90, 8 mt_op_go; 7 queues nothing and returns
    status_$mt_will_not_fit_thru_hatch. }
  mt_control_0 = 0;
  mt_control_1 = 1;
  mt_control_2 = 2;
  mt_control_3 = 3;
  mt_control_4 = 4;
  mt_control_5 = 5;
  mt_control_6 = 6;
  mt_control_7 = 7;
  mt_control_8 = 8;
  mt_op_control_0 = 16#20;
  mt_op_control_1 = 16#28;
  mt_op_control_2 = 16#1C;
  mt_op_control_3 = 16#40;
  mt_op_control_4 = 16#04;
  mt_op_control_5 = 16#38;
  mt_op_control_6 = 16#90;

  { The largest transfer a request takes, in bytes. }
  mt_max_length = 16384;

  { MT_$SET_MODE's mode set: pairs that clear or set one bit of the
    unit's state, 0/1 mode_bits member 11, 2/3 member 10, 4/5 member 12,
    6/7 the batch member (6 sets it), 8/9 the unit's flags member 9;
    members 10..15 must be clear, and a pair other than 8/9 may not ask
    for both. }
  mt_mode_clear_11 = 0;
  mt_mode_set_11 = 1;
  mt_mode_clear_10 = 2;
  mt_mode_set_10 = 3;
  mt_mode_clear_12 = 4;
  mt_mode_set_12 = 5;
  mt_mode_batch_on = 6;
  mt_mode_batch_off = 7;
  mt_mode_clear_flag_9 = 8;
  mt_mode_set_flag_9 = 9;
  mt_mode_bit_10 = 10;
  mt_mode_bit_11 = 11;
  mt_mode_bit_12 = 12;

  { The members of a unit's flag set (mt_$unit_t.flags): 15, the unit
    is acquired; 13, batch mode (requests are queued until an mt_op_go);
    12, a started request is outstanding (the caller has to wait before
    the next); 8, set while a request or the unit's queue is purged. }
  mt_unit_acquired = 15;
  mt_unit_batch = 13;
  mt_unit_pending = 12;
  mt_unit_purging = 8;
  mt_unit_flag_9 = 9;

  { Member 10 of a unit's flag set: set while MT_PURGE_UCB empties the
    unit's queue. }
  mt_unit_flushing = 10;
  mt_unit_flag_11 = 11;

  { Member 14 of a unit's flag set: the unit's I/O map region (iova_base,
    max_pages) is allocated; mt_$release_unit frees it. }
  mt_unit_mapped = 14;

  { The members of a request block's flag set (mt_$pb_t.flags): 15, its
    pages are to be unwired when it is retired (cleared when a page was
    wired already); 14, done (the finished requests mt_$queue_request
    retires); 13, set with 15 when the request is built. }
  mt_pb_unwire = 15;
  mt_pb_done = 14;
  mt_pb_built = 13;

  { The bound of a request block's page list: MT_$ACQUIRE builds the
    pool of blocks with the stride MT_$SCB's pb_size, 0x6C in the MT_ASM
    data, so a block is 0x6C bytes and its list from +0x28 holds 17
    longwords. }
  mt_max_ppns = 17;

  { The most pages the driver wires (the data block's list, mt/mt.pas). }
  mt_max_wired = 20;

type
  mt_$byte_t = [byte] 0..255;

  { A transfer's buffer, passed by address: mt_$queue_request records and
    checks its address.  MT_$READ's dump copies words into it from 0, so
    it is declared as words; the bound is the largest transfer. }
  mt_$buffer_t = array[0..mt_max_length div 2 - 1] of integer;

  { The MT page (the map's MT_PAGE section, 0xC00 bytes: the hand-written
    MT_ASM block, its code and MT_$SCB) as words, MT_$READ's dump. }
  mt_$page_words_t = array[0..1535] of integer;

  { A page's bytes, as MT_$SIO copies a chained transfer's header between
    the unit's header buffer and the page's end. }
  mt_$page_bytes_t = array[0..1023] of char;
  mt_$page_bytes_ptr_t = ^mt_$page_bytes_t;

  { A word of flags, member k bit k: the controller's, a unit's and a
    request block's flags, a unit's mode bits. }
  mt_$flag_set_t = set of 0..15;

  { One entry of MT_$WAIT's info array: three words of a request block
    (+0x16, +0x0C and the count at +0x10), for each block on the unit's
    queue.  The bound is the caller's. }
  mt_$wait_info_t = record
    tape_status: mt_$flag_set_t;          { 0x00: the block's tape_status }
    w_0c: integer;                        { 0x02: the block's +0x0C }
    count: pinteger;                      { 0x04: the block's count }
  end;
  mt_$wait_info_list_t = array[1..mt_max_length] of mt_$wait_info_t;

  { The controller's register page at PBU_MT_PAGE: the registers at
    +0x00, which MT_$ACQUIRE writes to reset the controller, and +0x01,
    which MT_$PRESENT probes and mt_$shutdown writes.  `[device]'. }
  mt_$page_t = [device] record
    reset: mt_$byte_t;                    { 0x00 }
    control: mt_$byte_t;                  { 0x01 }
  end;

  { MT_$SCB's flags word, two views (sock/sock.ins.pas's sock_$flags_t
    form): the set, and `state', the packed field of bits 14..12 (the
    enabled and busy flags and bit 12), which the routines clear
    together. }
  mt_$scb_flags_t = packed record
    case integer of
      1: (bits: mt_$flag_set_t);
      2: (wired: boolean;                 { bit 15 }
          state: 0..7;                    { bits 14..12 }
          unused: 0..4095);               { bits 11..0 }
  end;

  { A unit's mode bits, two views: the set MT_$SET_MODE changes member
    by member, and the drive field, bits 3..2, where MT_$ACQUIRE's unit
    setup stores a unit number of 0..3 (a larger one sets member 8
    instead, `high'); MT_$SIO reads the unit back from the two fields. }
  mt_$mode_bits_t = packed record
    case integer of
      1: (bits: mt_$flag_set_t);
      2: (unused_9: 0..127;               { bits 15..9 }
          high: 0..1;                     { bit 8 }
          unused_4: 0..15;                { bits 7..4 }
          drive: 0..3;                    { bits 3..2 }
          unused_0: 0..3);                { bits 1..0 }
  end;

  { A request block: the hand-written MT_$ENQ and MT_$DEQ link the
    blocks through `next' into a unit's queue or the free queue.  0x6C bytes
    (MT_$SCB's pb_size). }
  mt_$long_ptr_t = ^integer32;
  mt_$pb_ptr_t = ^mt_$pb_t;
  mt_$buffer_ptr_t = ^mt_$buffer_t;
  mt_$pb_t = record
    next: mt_$pb_ptr_t;                   { 0x00 }
    flags: mt_$flag_set_t;                { 0x04 }
    op: integer;                          { 0x06 }
    unused_08: integer;                   { 0x08 }
    mode_bits: mt_$mode_bits_t;           { 0x0A: the unit's mode_bits }
    word_0c: integer;                     { 0x0C }
    length: pinteger;                     { 0x0E: a transfer's bytes }
    count: pinteger;                      { 0x10: another request's count }
    iova: integer32;                      { 0x12: MT_$PUTIOVA's }
    tape_status: mt_$flag_set_t;          { 0x16: MT_$WAIT reports it }
    unused_18: integer32;                 { 0x18 }
    header: linteger;                     { 0x1C: the header's address, or 0 }
    buffer: linteger;                     { 0x20: the buffer's address }
    hdr_offset: integer;                  { 0x24: the unit's hdr_offset }
    npages: pinteger;                     { 0x26 }
    ppns: array[1..mt_max_ppns] of integer32; { 0x28: PBU_$SAVE_PPN's }
  end;

  { A queue of request blocks: the first block, and the address of the
    last block's `next' (of `head' when the queue is empty), as MT_$ENQ
    appends and MT_$DEQ takes. }
  mt_$queue_t = record
    head: mt_$pb_ptr_t;                   { 0x00 }
    tail: ^mt_$pb_ptr_t;                  { 0x04 }
  end;
  mt_$queue_ptr_t = ^mt_$queue_t;

  { The header page's physical address, MT_$ACQUIRE's: the page number
    PBU_$SAVE_PPN returns, above the offset in the page. }
  mt_$phys_addr_t = packed record
    ppn: 0..4194303;                      { bits 31..10 }
    offset: 0..1023;                      { bits 9..0 }
  end;

  { A unit's flags word, two views as MT_$SCB's: the set, and `pending',
    bit 12 as a packed field, which mt_$queue_request stores a boolean
    into. }
  mt_$unit_flags_t = packed record
    case integer of
      1: (bits: mt_$flag_set_t);
      2: (acquired: boolean;              { bit 15 }
          unused_14: boolean;             { bit 14 }
          batch: boolean;                 { bit 13 }
          pending: boolean;               { bit 12 }
          unused: 0..4095);               { bits 11..0 }
  end;

  { A tape unit's record in MT_$SCB, 0x2E bytes (the stride of the
    routines' indexing).  The units are linked in a ring by `next', which
    MT_$SIO follows from MT_$SCB's cursor. }
  mt_$unit_ptr_t = ^mt_$unit_t;
  mt_$unit_t = record
    queue: mt_$queue_t;                   { 0x00: its requests }
    flags: mt_$unit_flags_t;              { 0x08 }
    pbu_unit: integer;                    { 0x0A: the unit's PBU unit, the
                                            PBU calls' first }
    dcte: pbu_$dcte_ptr_t;                { 0x0C: PBU_$GET_PTR's DCTE }
    iova_base: integer32;                 { 0x10: or'ed into the iova }
    max_pages: integer;                   { 0x14: the most per request }
    mode_bits: mt_$mode_bits_t;           { 0x16: MT_$SET_MODE's bits, a
                                            request's mode_bits }
    wait_count: integer;                  { 0x18: MT_$WAIT's count, then 0 }
    hdr_offset: integer;                  { 0x1A: the header's offset in
                                            its page (chained transfers) }
    hdr_addr: linteger;                   { 0x1C: the unit's header buffer's
                                            address, or 0 }
    hdr_pa: mt_$phys_addr_t;              { 0x20: the header page's }
    unused_24: integer;                   { 0x24 }
    l_26: integer32;                      { 0x26: cleared at setup }
    next: mt_$unit_ptr_t;                 { 0x2A: the next unit, a ring }
  end;

  { MT_$SCB (map symbol, in the MT page's hand-written MT_ASM data), the
    controller's block.  A control word and its I/O address, the free
    queue of request blocks at +0x12, the MT page's I/O map region (its
    pages' addresses +0x1A and count +0x26, freed when the last unit is
    released), the request blocks' size at +0x28, the number of units
    at +0x2E, the number of acquired units at +0x30, the controller's
    flags at +0x32, a new unit's mode bits at +0x34, the units' records
    from +0x3C (two of 0x2E bytes), and the pool of request blocks from
    +0x98 to the end of the MT page.  The pool's bound and the other
    words are stand-ins. }
  mt_$scb_t = record
    unused_00: integer;                   { 0x00 }
    ctl_iova: integer32;                  { 0x02: ctl_word's I/O address }
    ctl_word: integer;                    { 0x06: 16#11FF until the
                                            controller answers its reset }
    cmd_iova: integer32;                  { 0x08: the started block's I/O
                                            address }
    unused_0c: integer;                   { 0x0C }
    current: mt_$pb_ptr_t;                { 0x0E: the started block }
    free_q: mt_$queue_t;                  { 0x12 }
    cfg_iova: array[1..3] of linteger;    { 0x1A: the MT page's I/O
                                            addresses }
    cfg_pages: integer;                   { 0x26 }
    pb_size: integer;                     { 0x28: a request block's size }
    cursor: mt_$unit_ptr_t;               { 0x2A: MT_$SIO's next unit }
    n_units: integer;                     { 0x2E }
    n_acquired: integer;                  { 0x30 }
    flags: mt_$scb_flags_t;               { 0x32 }
    default_mode: mt_$mode_bits_t;        { 0x34: a new unit's mode_bits }
    n_spurious: integer;                  { 0x36: interrupts with no block }
    cur_dcte: pbu_$dcte_ptr_t;            { 0x38: the last finished unit's }
    units: array[0..1] of mt_$unit_t;     { 0x3C }
    case integer of
      1: (pool: array[0..1] of integer32);  { 0x98: the request blocks, to
                                              the MT page's end }
      2: (unused_98: array[1..360] of integer;
          w_368: integer;                   { 0x368 }
          iova_36a: integer32);             { 0x36A }
  end;

var
  mt_$scb: extern mt_$scb_t;

  { MT_$INT (map symbol, the MT page's first code: hand assembly), the
    controller's interrupt routine, which MT_$ACQUIRE gives
    PBU_$ACQUIRE_INT by address. }
  mt_$int: extern char;

  { MT_$PAGE_END (map symbol, the MT page's last byte) and MT_$PROC_START
    and MT_$PROC_END (map symbols, the MT_$SIO segment's first byte and
    MT_END_ADDR's): MT_$ACQUIRE wires the page and the MT_$SIO code by
    them. }
  mt_$page_end: extern char;
  mt_$proc_start: extern char;
  mt_$proc_end: extern char;

  { MT_$PAGE_START (map symbol, the MT page's first byte). }
  mt_$page_start: extern mt_$page_words_t;

  { PBU_MT_PAGE (map symbol of the I/O definitions, no `$'). }
  pbu_mt_page: extern mt_$page_t;

  { IOMAP, the I/O map mt_$set_iomap writes: pbu/pbu.ins.pas's. }

{ The PBU routines MT calls (PBU_$DISABLE_DEVICE, _$ENABLE_DEVICE,
  _$SAVE_PPN, _$FREE, _$DELETE_PPN, _$RELEASE_INT, _$WAIT and its
  results, PBU2_$WIRE, PBU2_$UNWIRE): pbu/pbu.ins.pas, which mt/mt.pas
  includes. }

{ MT_$ENQ, MT_$DEQ, MT_$PUTIOVA and MT_$MT_BUSY (the MT page's hand
  assembly): MT_$ENQ appends a block to a queue, with the interrupts
  masked; MT_$DEQ returns a queue's first block (nil when it is empty);
  MT_$PUTIOVA writes an I/O address formed from a value; MT_$MT_BUSY
  tests and sets the controller's busy member and returns whether it
  was set. }
procedure mt_$enq(var queue: mt_$queue_t; in pb: mt_$pb_ptr_t); extern;
function mt_$deq(var queue: mt_$queue_t): mt_$pb_ptr_t; extern;
procedure mt_$putiova(value: integer32; out iova: integer32);
  options(extern, val_param);
function mt_$mt_busy: boolean; extern;

{ MT_$PB_WIRED (the MT page's hand assembly): clears a request block's
  member 15 (mt_pb_unwire) and returns whether it was set. }
function mt_$pb_wired(var pb: mt_$pb_t): boolean; extern;

{ MT_PURGE_UCB - empty a tape unit's request queue. }
procedure mt_purge_ucb(in unit: integer); extern;

{ MT_$SIO - finish the controller's current request and start the next. }
function mt_$sio(in unit_rec: mt_$unit_ptr_t): integer; extern;

{ MT_$GETIOVA (the MT page's hand assembly): MT_$PUTIOVA's inverse, a
  request block's I/O map entry form in, its I/O address out. }
function mt_$getiova(iova: integer32): linteger;
  options(extern, val_param);

{ MT_$PURGE_PB - unwire a request block's pages and, when asked, free the
  block. }
procedure mt_$purge_pb(in unit: integer; in pb: mt_$pb_ptr_t;
                       in release: boolean); extern;

{ MT_$PRESENT - report whether the magnetic tape controller is present. }
function mt_$present: boolean; extern;

{ MT_$WRITE - write a buffer to a magnetic tape unit. }
procedure mt_$write(in unit: integer; in buffer: univ mt_$buffer_t;
                    in length: pinteger; out status: status_$t); extern;

{ MT_$READ - read a block from a magnetic tape unit into a buffer. }
procedure mt_$read(in unit: integer; var buffer: univ mt_$buffer_t;
                   in length: integer; out status: status_$t); extern;

{ MT_$ERASE - erase tape on a magnetic tape unit. }
procedure mt_$erase(in unit: integer; in option: integer;
                    in count: integer; out status: status_$t); extern;

{ MT_$CONTROL - queue a control operation on a magnetic tape unit. }
procedure mt_$control(in unit: integer; in func: integer;
                      out status: status_$t); extern;

{ MT_$WAIT - wait for a tape unit's started requests and report them. }
procedure mt_$wait(in unit: integer; in timeout: integer;
                   out info: univ mt_$wait_info_list_t; in max: integer;
                   out count: integer; out status: status_$t);
  extern;

{ MT_$ACQUIRE - acquire a magnetic tape unit for the calling process. }
procedure mt_$acquire(in unit: pinteger; in max_length: pinteger;
                      in header: linteger; out status: status_$t);
  extern;

{ MT_$GET_IOVA - the I/O address of an object in the MT page. }
function mt_$get_iova(va: univ_ptr): integer32;
  options(extern, val_param);

{ MT_$SET_MODE - set a magnetic tape unit's mode bits. }
procedure mt_$set_mode(in unit: integer; in mode: mt_$flag_set_t;
                       in param3: integer32; out status: status_$t);
  extern;

{ MT_$CHAIN_READ - read a block with a header into two buffers on a
  magnetic tape unit. }
procedure mt_$chain_read(in unit: integer; var header: univ mt_$buffer_t;
                         in hdr_length: pinteger;
                         var buffer: univ mt_$buffer_t;
                         in length: pinteger; out status: status_$t);
  extern;

{ MT_$CHAIN_WRITE - write a block with a header from two buffers on a
  magnetic tape unit. }
procedure mt_$chain_write(in unit: integer; in header: univ mt_$buffer_t;
                          in hdr_length: pinteger;
                          in buffer: univ mt_$buffer_t;
                          in length: pinteger; out status: status_$t);
  extern;

{ MT_$SPACE - space the tape on a magnetic tape unit. }
procedure mt_$space(in unit: integer; in mode: integer;
                    in count: integer; out status: status_$t); extern;

{ MT_$UNWIRE - unwire a user buffer the driver had wired for a tape unit. }
procedure mt_$unwire(in unit: integer; var buffer: univ mt_$buffer_t;
                     in length: linteger; out status: status_$t); extern;

{ MT_$WIRE - wire a user buffer for transfers on a tape unit. }
procedure mt_$wire(in unit: integer; in buffer: univ mt_$buffer_t;
                   in length: linteger; out status: status_$t); extern;
%endif
