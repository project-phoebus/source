{ time/time.ins.pas - TIME_$ routines, for the Domain Pascal tree.

  The TIME_ modules' constants, types, variables and map-global routine
  headings, in map order (TIME_, TIME_Q_, the hand-written TIME_ASM,
  TIME_$INIT, TIME_UNWIRED).  The constants and the rel/abs type are
  Apollo's customer time.ins.pas of SR10.2.  Include base/base.ins.pas
  and ec/ec.ins.pas before it.
}

const
  { Apollo's customer time.ins.pas (SR10.2), line 15: `time_$wait_quit =
    16#000D0003' ("wait interrupted by quit fault"; stcode.db.10.2 "quit
    while waiting for event").  PKT_$SEND_INTERNET compares TIME_$WAIT's
    status with it. }
  time_$wait_quit = 16#000D0003;

  { The other statuses of Apollo's customer time.ins.pas of SR10.2 that
    the TIME_ routines store or test, with its names and values (the
    comments are Apollo's):
    - time_$bad_key: TIME_$GET_EC;
    - time_$itimer_real, time_$itimer_virtual, time_$cpu_limit_f: the
      constant cells passed to PROC2_$SIGNAL_OS by the three TIME_UNWIRED
      callbacks;
    - time_$q_elem_not_in_use, time_$q_elem_not_found:
      time_$q_remove_internal's stores, TIME_$Q_REENTER_ELEM's and
      TIME_$CANCEL's compares;
    - time_$bad_delta: TIME_$ADJUST_TIME_OF_DAY;
    - time_$q_elem_in_use: the crash cell of time_$q_insert_sorted and
      TIME_$WAIT;
    - time_$bad_relative_time: time_$set_itimer_internal. }
  time_$bad_key = 16#000D0005;             { bad key to time_$get_ec }
  time_$itimer_real = 16#000D0007;         { real interval timer fault }
  time_$itimer_virtual = 16#000D0008;      { virtual interval timer fault }
  time_$q_elem_not_in_use = 16#000D0009;   { tried to free an element not
                                             on a queue }
  time_$q_elem_not_found = 16#000D000A;    { tried to free something
                                             that's not an element }
  time_$cpu_limit_f = 16#000D000B;         { cpu time limit fault }
  time_$bad_delta = 16#000D000C;           { tried to adjust time with too
                                             big a delta }
  time_$q_elem_in_use = 16#000D000D;       { tried to use element already
                                             in use }
  time_$bad_relative_time = 16#000D000E;   { relative time is too large }

type
  { Relative or absolute time, a word (the customer time.ins.pas of
    SR10.2, sr10.2-install/.../sys/ins/time.ins.pas: `time_$rel_abs_t =
    (time_$relative, time_$absolute)', the type of TIME_$WAIT's first
    parameter there).  TIME_$WAIT passes its own first argument on to
    TIME_$ADVANCE's (below), and compares it with 1. }
  time_$rel_abs_t = (time_$relative, time_$absolute);

  { An element of a time queue, 0x1A bytes.  The clocks are 6-byte clocks:
    TIME_$Q_ADD_CALLBACK copies a clock into each and passes the first to
    ADD48 by address.  flags is a set: its members are tested on the low
    byte of the word, and it is cleared and tested whole.  The pointers
    have no Pascal type yet: univ_ptr (next links elements, callback is a
    routine, callback_arg is what TIME_$ADVANCE hands it, the
    eventcount's address). }
  time_$queue_elem_t = record
    next: univ_ptr;                       { 0x00 }
    callback: univ_ptr;                   { 0x04 }
    callback_arg: univ_ptr;               { 0x08 }
    expire: time_$clock_t;                { 0x0C }
    flags: set of 0..15;                  { 0x12 }
    interval: time_$clock_t;              { 0x14 }
  end;

  { A time queue, 0xC bytes: the first element, the spin lock, the
    virtual-timer flag, the queue id.  TIME_$Q_ENTER_ELEM locks the
    queue's +4. }
  time_$queue_t = record
    head: univ_ptr;                       { 0x00 }
    lock: integer32;                      { 0x04 }
    virtual: boolean;                     { 0x08 }
    pad_09: char;                         { 0x09 }
    queue_id: pinteger;                   { 0x0A }
  end;

  { A queue element's flags as a value (time_$queue_elem_t's flags,
    above): TIME_$Q_ADD_CALLBACK takes them by value. }
  time_$qelem_flags_t = set of 0..15;

  { A pointer to a queue element: the queue's head and each element's
    next hold one (univ_ptr above, converted at each use), and an
    element's callback is called with one passed by address
    (TIME_$Q_SCAN_QUEUE). }
  time_$queue_elem_ptr_t = ^time_$queue_elem_t;

  { An element's callback, as TIME_$Q_SCAN_QUEUE calls it (above): the
    element's pointer by address, the default convention.
    TIME_$ADVANCE_CALLBACK reads it so. }
  time_$callback_t = ^procedure(in elem: time_$queue_elem_ptr_t);

  { Time in seconds and microseconds, Apollo's customer base.ins.pas of
    SR10.2 (`time_$timeval_t = RECORD sec: integer32; usec: integer32;
    END', added there 08/17/87): TIME_$GET_ADJUST stores the two
    longwords at 0 and 4, TIME_$SET_TIME_OF_DAY and
    TIME_$ADJUST_TIME_OF_DAY read them, and TIME_$CURRENT_TIME (below) is
    one. }
  time_$timeval_t = record
    sec: integer32;                       { 0x00 }
    usec: integer32;                      { 0x04 }
  end;

  { A record of the CPU-limit and interval-timer databases (below): a
    queue element and 2 bytes, 0x1C: the code scales the address space by
    28 and reaches the element's fields at +0xC, +0x10 and +0x13.  dpc's
    element is 0x1A bytes (its own size, not rounded to the longword: a
    probe unit's array of two is 52 bytes), so the 2 bytes are a field
    here. }
  time_$db_rec_t = record
    elem: time_$queue_elem_t;             { 0x00 }
    pad_1a: pinteger;                     { 0x1A }
  end;

  { One record per address space, 0..57 (58 * 0x1C = 0x658, the distance
    from TIME_$CPU_LIMIT_DB to TIME_$ITIMER_DB and from the real half of
    TIME_$ITIMER_DB to the virtual one).  The address space is
    PROC1_$AS_ID, from 0 at the symbol (no displacement in the index). }
  time_$db_t = array[0..57] of time_$db_rec_t;

var
  { TIME_$CURRENT_CLOCKH (map symbol, MARKED, in the hand-written
    TIME_ASM data segment of WIRED_DATA, after TIME_$CLOCKH): the high 32
    bits of the current clock.  LOG_$ADD reads it as a longword by its
    absolute address: another unit's variable.  The type is the customer
    base.ins.pas's for the high half of the clock, time_$clockh_t
    (base/base.ins.pas). }
  time_$current_clockh: extern time_$clockh_t;

  { TIME_$CLOCKH (map symbol, MARKED, in the same hand-written segment;
    TIME_$CLOCKH_EC has the same address, the eventcount whose value it
    is): the high 32 bits of the clock.  UID_$GEN reads it as a longword
    by its absolute address and compares the difference unsigned:
    time_$clockh_t (base/base.ins.pas). }
  time_$clockh: extern time_$clockh_t;

  { TIME_$BOOT_TIME (map symbol, in the hand-written TIME_ASM data
    segment, after TIME_$CURRENT_CLOCKH): the high 32 bits of the clock
    at boot.  BAT_$MOUNT copies it as a longword by its absolute address:
    another unit's variable, time_$clockh_t as its neighbors. }
  time_$boot_time: extern time_$clockh_t;

  { TIME_$RTEQ (map symbol, in TIME_'s data segment, after TIME_$VTQ):
    the real-time queue.  SIO_$I_TSTART passes its address, as another
    unit's variable. }
  time_$rteq: extern time_$queue_t;

  { The TIME_ module's map-symbol variables in TIME_'s data segment
    (WIRED_DATA), all zero in the image: defined by time/time.pas, which
    lays out the block; reached absolutely by the other two modules and
    by TIME_$INIT.
    - TIME_$CPU_LIMIT_DB (+0x000) and TIME_$ITIMER_DB (+0x658): the
      databases (types above); TIME_$ITIMER_DB is two of them, real [0]
      and virtual [1];
    - TIME_$VTQ (+0x1308): the virtual-timer queues, one per process from
      1, 64 of 0xC bytes up to TIME_$RTEQ (TIME_$INIT's loop of 64);
    - TIME_$SYS_FREQ (+0x1624): no reference in the image (a byte search
      finds no operand with its address); 4 bytes up to the block's end,
      a longword. }
  time_$cpu_limit_db: extern time_$db_t;
  time_$itimer_db: extern array[0..1] of time_$db_t;
  time_$vtq: extern array[1..64] of time_$queue_t;
  time_$sys_freq: extern linteger;

  { TIME_ASM's data (the hand-written TIME_ASM data segment, WIRED_DATA;
    map symbols), as the compiled TIME_ routines reach them by their
    absolute addresses:
    - IN_VT_INT, IN_RT_INT (map symbols without `$', globals): booleans,
      cleared by TIME_$VT_INT and TIME_$RTE_INT and tested for their sign by
      TIME_$Q_ENTER_ELEM; the timer handler sets them
      (time/m68k/timer_handler.s);
    - TIME_$FAST_CLOCK_EC and TIME_$CLOCKH_EC: two eventcounts (12 bytes
      each, the next symbols' distance), whose addresses TIME_$GET_EC
      passes to EC2_$REGISTER_EC1.  TIME_$CLOCKH (above) has the same
      address: the clock's high half is that eventcount's value;
    - TIME_$CLOCKL and TIME_$CURRENT_CLOCKL: the low words of the two
      clocks, stored as words (TIME_$INIT); TIME_$SET_TIME_OF_DAY
      subtracts the first from a word and zero-extends the result:
      pinteger, the low half of time_$clock_t;
    - TIME_$CURRENT_TIME: the time of day, a time_$timeval_t (the
      microseconds at +4 have no map symbol), stored by TIME_$INIT and
      TIME_$SET_TIME_OF_DAY; 8 bytes to TIME_$CURRENT_TICK;
    - TIME_$CURRENT_TICK: the tick period, a word, 4167 (TIME_$INIT),
      the skew plus 4167 (TIME_$ADJUST_TIME_OF_DAY): integer;
    - TIME_$CURRENT_SKEW: a word, negated as signed and stored: integer;
    - TIME_$CURRENT_DELTA: a longword, divided signed: integer32.
    The names are the map's; the types are inferred where the code does not
    say more. }
  in_vt_int: extern boolean;
  in_rt_int: extern boolean;
  time_$fast_clock_ec: extern ec_$eventcount_t;
  time_$clockh_ec: extern ec_$eventcount_t;
  time_$clockl: extern pinteger;
  time_$current_clockl: extern pinteger;
  time_$current_time: extern time_$timeval_t;
  time_$current_tick: extern integer;
  time_$current_skew: extern integer;
  time_$current_delta: extern integer32;

{ ---- Routine headings, in map order.  TIMER_$INIT, the first routine
  of TIME_'s code segment, has its heading in timer/timer.ins.pas. ---- }

{ TIME_$RTE_INT - the real-time timer's deferred interrupt routine.
  TIME_$VT_INT - the virtual timer's deferred interrupt routine. }
function time_$rte_int(data: univ_ptr): ec_$eventcount_ptr_t;
  options(extern, val_param);
function time_$vt_int(data: univ_ptr): ec_$eventcount_ptr_t;
  options(extern, val_param);

{ TIME_$ADVANCE_CALLBACK - the callback that advances a waiter's eventcount. }
procedure time_$advance_callback(in elem: time_$queue_elem_ptr_t); extern;

{ TIME_$ADVANCE - arrange for an eventcount to be advanced at a time. }
procedure time_$advance(in is_absolute: time_$rel_abs_t;
                        in when: time_$clock_t;
                        var ec: ec_$eventcount_t;
                        var elem: time_$queue_elem_t;
                        out status: status_$t); extern;

{ TIME_$CANCEL - cancel a pending TIME_$ADVANCE. }
procedure time_$cancel(wait_value: integer32;
                       var elem: time_$queue_elem_t;
                       out status: status_$t);
  options(extern, val_param);

{ TIME_$WAIT - wait until a time, or until a quit. }
procedure time_$wait(in rel_abs: time_$rel_abs_t; in exp_time: time_$clock_t;
                     out status: status_$t); extern;

{ TIME_$WAIT2 - wait until a time or until an eventcount reaches a value. }
function time_$wait2(rel_abs: time_$rel_abs_t; in delay: time_$clock_t;
                     var ec: ec_$eventcount_t; in wait_value: integer32;
                     out status: status_$t): boolean; extern;

{ TIME_$GET_EC - the level-2 handle of a clock eventcount. }
procedure time_$get_ec(in key: integer; out ecp: ec2_$ptr_t;
                       out status: status_$t); extern;

{ TIME_$SET_TIME_OF_DAY - set the time of day and the calendar. }
procedure time_$set_time_of_day(in tv: time_$timeval_t;
                                out status: status_$t); extern;

{ TIME_$ADJUST_TIME_OF_DAY - adjust the clock gradually by a delta. }
procedure time_$adjust_time_of_day(in delta: time_$timeval_t;
                                   out old_delta: time_$timeval_t;
                                   out status: status_$t); extern;

{ TIME_$GET_ADJUST - the clock adjustment still to be applied. }
procedure time_$get_adjust(out delta: time_$timeval_t); extern;

{ TIME_$Q_INIT - initialize the time-queue subsystem. }
procedure time_$q_init; extern;

{ TIME_$Q_INIT_QUEUE - initialize a time queue. }
procedure time_$q_init_queue(virtual: boolean; queue_id: pinteger;
                             out queue: time_$queue_t);
  options(extern, val_param);

{ TIME_$Q_FLUSH_QUEUE - empty a time queue. }
procedure time_$q_flush_queue(var queue: time_$queue_t); extern;

{ TIME_$Q_REENTER_ELEM - requeue an element at a new expiry. }
procedure time_$q_reenter_elem(var queue: time_$queue_t;
                               in when: time_$clock_t;
                               is_absolute: time_$rel_abs_t;
                               in now: time_$clock_t;
                               var elem: time_$queue_elem_t;
                               out status: status_$t);
  options(extern, val_param);

{ TIME_$Q_ENTER_ELEM - put an element on a time queue. }
procedure time_$q_enter_elem(var queue: time_$queue_t;
                             in now: time_$clock_t;
                             var elem: time_$queue_elem_t;
                             out status: status_$t); extern;

{ TIME_$Q_ADD_CALLBACK - fill a queue element with a callback and queue it. }
procedure time_$q_add_callback(var queue: time_$queue_t;
                               in when: time_$clock_t;
                               is_absolute: time_$rel_abs_t;
                               in now: time_$clock_t;
                               callback: univ_ptr;
                               callback_arg: univ_ptr;
                               flags: time_$qelem_flags_t;
                               in interval: univ time_$clock_t;
                               var qelem: time_$queue_elem_t;
                               out status: status_$t);
  options(extern, val_param);

{ TIME_$Q_REMOVE_ELEM - take an element off a time queue. }
procedure time_$q_remove_elem(var queue: time_$queue_t;
                              var elem: time_$queue_elem_t;
                              out status: status_$t); extern;

{ TIME_$Q_SCAN_QUEUE - run a time queue's expired elements. }
procedure time_$q_scan_queue(var queue: time_$queue_t;
                             in now: time_$clock_t;
                             out status: status_$t); extern;

{ The hand-written routines of TIME_ASM (its code segment: ADD48,
  SUB48, in cal/cal.ins.pas; its data segment: the rest) follow, as
  their compiled callers use them.  TIME_$WRT_VT_TIMER takes its
  argument in a register (time/m68k/time_asm.s; PROC1's dispatcher
  calls it from assembly), so it has no Pascal heading.  TIME_$VT_TIMER
  takes none and has a compiled caller (below). }

{ TIME_$VT_TIMER (hand assembly in TIME_ASM's data segment): no
  arguments, the virtual timer's count in D0's word (0 when the timer
  has expired), A0 clobbered.  PROC1_$SET_VT calls it with nothing
  pushed and subtracts the word from the PCB's vtimer: an integer
  function (signed word arithmetic). }
function time_$vt_timer: integer; extern;

{ TIME_$READ_CAL (hand assembly in TIME_ASM's data segment, a jump into
  the calendar code before it): reads the calendar chip and stores a
  clock and a seconds count.  Its one compiled caller, TIME_$INIT,
  pushes two frame addresses, and reads the clock and the seconds,
  which it rebases from 1980 to 1970: `out', both by address.  The seconds a
  longword, integer32. }
procedure time_$read_cal(out clock: time_$clock_t; out secs: integer32);
  extern;

{ TIME_$WRT_TIMER (hand-written, in TIME_ASM's data segment): reads two
  addresses off the stack, the timer's index and the value, and writes
  the value to the timer's counter; it writes neither argument: `in',
  both by address (the default convention).  Its compiled callers push
  two addresses, the value first: TIMER_$INIT (constant cells:
  timer/init.pas), time_$q_setup_timer, PROC1_$SET_VT.  The index is
  zero-extended, the values include 16#FFFF (TIMER_$INIT's cell): both
  pinteger. }
procedure time_$wrt_timer(in timer_index: pinteger; in value: pinteger);
  extern;

{ TIME_$CLOCK (hand-written): reads the 48-bit clock and stores it
  through its one argument, read off the stack: six bytes written, none
  read.  Its compiled callers push one address: TTY_$I_RCV and
  TTY_$I_STORE_PARITY, the descriptor's last_input_clock.  So by address
  under the default convention, and `out'.  The customer time.ins.pas of
  SR10.2 declares it so: `PROCEDURE time_$clock(OUT now: time_$clock_t);
  EXTERN;', whose parameter name is used. }
procedure time_$clock(out now: time_$clock_t); extern;

{ TIME_$ABS_CLOCK (hand-written, in TIME_ASM's data segment): reads the
  timer and the high clock with interrupts off and stores the 48-bit
  clock through the address on the stack, never reading the old value.
  UID_$GEN passes a frame record and reads its first longword and its
  last word.  So one `out' time_$clock_t by address.  `univ':
  ring_$receive_packet passes the six bytes at +4 of a socket packet record,
  its src_addr and src_port, an integer32 field (sock/sock.ins.pas
  sock_$pkt_info_t); the other callers' clocks pass as before (ref 5.3.3: a
  `univ' formal takes an argument of any type by address). }
procedure time_$abs_clock(out clock: univ time_$clock_t); extern;

{ TIME_$GET_TIME_OF_DAY (hand assembly in TIME_ASM's data segment):
  stores the time of day, two longwords, through its one argument, with
  interrupts off.  TIME_$ADJUST_TIME_OF_DAY pushes a frame record and
  reads both longwords: `out' time_$timeval_t by address. }
procedure time_$get_time_of_day(out tv: time_$timeval_t); extern;

{ TIME_$SET_VECTOR (hand-written, in TIME_ASM's data segment): installs
  the timer interrupt handler in the vector at 0x78 and reads no
  argument.  Its one caller, TIMER_$INIT, pushes nothing
  (timer/init.pas).  No parameters. }
procedure time_$set_vector; extern;

{ TIME_$INIT - initialize the clocks and the time queues. }
procedure time_$init(in read_calendar: boolean); extern;

{ The TIME_UNWIRED module (time/time_unwired.pas). }

{ TIME_$SET_ITIMER_REAL_CALLBACK, _VIRT_CALLBACK and
  TIME_$SET_CPU_LIMIT_CALLBACK (compiled, globals): the callbacks
  time_$set_itimer_internal and TIME_$SET_CPU_LIMIT queue, with the
  element flag that sends them through DXM_$UNWIRED_Q.  DXM_$SCAN_QUEUE
  calls a callback with the address of a pointer to its copy of the
  datum (dxm/dxm.ins.pas, DXM_$ADD_CALLBACK), here the address space as
  a longword; the body reads the slot, the pointer, and the datum's low
  word.  So one `in' parameter by address, a pointer to a 4-byte record
  whose second word is the address space (time_$callback_arg_ptr_t,
  below). }
type
  { The datum the TIME_UNWIRED callbacks get (above): a longword holding
    the address space, read as its low word at +2. }
  time_$callback_arg_t = record
    unused_0: pinteger;                   { 0x00: the longword's high
                                            word, 0 }
    as_id: integer;                       { 0x02 }
  end;
  time_$callback_arg_ptr_t = ^time_$callback_arg_t;

procedure time_$set_itimer_real_callback(in arg: time_$callback_arg_ptr_t);
  extern;
procedure time_$set_itimer_virt_callback(in arg: time_$callback_arg_ptr_t);
  extern;
procedure time_$set_cpu_limit_callback(in arg: time_$callback_arg_ptr_t);
  extern;

{ TIME_$RELEASE - stop the current address space's interval timers. }
procedure time_$release; extern;

{ TIME_$SET_ITIMER - set the current address space's interval timer. }
procedure time_$set_itimer(in which: integer; in interval: time_$clock_t;
                           in value: time_$clock_t;
                           in out ointerval: time_$clock_t;
                           in out ovalue: time_$clock_t;
                           out status: status_$t); extern;

{ TIME_$GET_ITIMER - read the current address space's interval timer. }
procedure time_$get_itimer(in which: integer;
                           in out interval: time_$clock_t;
                           in out value: time_$clock_t); extern;

{ TIME_$SET_CPU_LIMIT - set the current address space's CPU time limit. }
procedure time_$set_cpu_limit(in limit: time_$clock_t; in relative: boolean;
                              out status: status_$t); extern;

{ TIME_$GET_EC's key (its `case key of'): 0 is Apollo's time.ins.pas
  time_$key_t's one enumerator, time_$clockh_key (as a constant here:
  this tree's heading takes the key as a word); 1, the fast clock's, has
  no Apollo name and is new. }
const
  time_$clockh_key = 0;
  time_$fast_clock_key = 1;
