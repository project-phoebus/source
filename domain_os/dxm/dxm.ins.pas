{ dxm/dxm.ins.pas - the deferred execution manager (DXM_$), for the Domain
  Pascal tree.

  The constants, the queue and entry types, the module's three global
  variables and its eight routines' headings; the module is
  dxm/dxm.pas.  No customer insert file declares anything of DXM; the
  globals' names are the map's.

  Include base/base.ins.pas and ec/ec.ins.pas before it.
}

const
  { The longest datum a queue entry holds.  DXM_$ADD_CALLBACK crashes
    above it, and the entry's data field is 12 bytes (dxm_$entry_t). }
  dxm_max_data_size = 12;

  { 16#00170001, "no more deferred execution queue slots" (OS / deferred
    execution module manager, stcode.db.10.2).  DXM_$ADD_CALLBACK stores
    it when the queue is full. }
  status_$dxm_no_more_deferred_execution_queue_slots = 16#00170001;

  { 16#00170002, "datum too large for deferred execution" (the same
    subsystem, stcode.db.10.2).  The name is made from the text with the
    prefix of its neighbor above, as base/base.ins.pas makes the terminal
    manager's.  DXM_$ADD_CALLBACK passes it to CRASH_SYSTEM by address,
    from a cell of its code. }
  status_$dxm_datum_too_large_for_deferred_execution = 16#00170002;

type
  { An unsigned word.  DXM_$ADD_CALLBACK compares its data_size unsigned
    and zero-extends it.  A parameter's type must be a type name (ref
    5.1, p. 5-2). }
  dxm_$uword_t = 0..65535;

  { The 12 bytes of an entry's datum, read two ways: DXM_$ADD_CALLBACK
    copies it in longwords, (data_size + 3) div 4 of them, and compares
    it byte by byte, data_size bytes.  Both are 1-based arrays (the -4
    and -1 folded into the displacements).  A record with two variants
    (ref 3.10.3) gives both readings of the one object. }
  dxm_$data_t = record
    case integer of
      1: (longs: array[1..3] of integer32);   { 0x00 }
      2: (bytes: array[1..12] of char);       { 0x00 }
  end;

  dxm_$data_ptr_t = ^dxm_$data_t;

  { A queued routine.  DXM_$SCAN_QUEUE calls it through the entry with
    one argument by address, the slot of a pointer to the entry's datum,
    and no options (no by-value argument).  The routines queued so
    declare the parameter `in' with their own pointer types
    (TTY_$I_DXM_SIGNAL, TERM_$ENQUEUE_TPAD, DXM_$ADD_SIGNAL_CALLBACK);
    none of them is assigned to this type (their addresses reach the
    queue through DXM_$ADD_CALLBACK's `univ' parameter), so its
    parameter is univ_ptr. }
  dxm_$callback_t = ^procedure(in data: univ_ptr);

  { A queue entry, 16 bytes: the callback at 0, the datum at 4.
    DXM_$ADD_CALLBACK stores them, DXM_$SCAN_QUEUE reads them; the index
    is scaled by 16. }
  dxm_$entry_t = record
    callback: dxm_$callback_t;            { 0x00 }
    data: dxm_$data_t;                    { 0x04 }
  end;

  dxm_$entry_ptr_t = ^dxm_$entry_t;

  { A queue's ring of entries, reached through the queue's pointer and
    indexed from 0 (no displacement).  The two rings have 64 and 32
    entries (dxm/dxm.pas, the data); one pointer type serves both, so
    the array is the one-element formal of tty_$chars_t
    (tty/tty.ins.pas), indexed beyond its bound. }
  dxm_$entries_t = array[0..0] of dxm_$entry_t;
  dxm_$entries_ptr_t = ^dxm_$entries_t;

  { A deferred execution queue, 28 bytes: head 0x00, tail 0x02, mask
    0x04, lock 0x08, ec 0x0C, entries 0x18.  lock is passed by address
    to ML_$SPIN_LOCK, whose heading takes an integer32 (ml/ml.ins.pas).
    entries points at the ring, dxm_$entries_ptr_t: the routines index
    it as an array of 16-byte entries (above). }
  dxm_$queue_t = record
    head: dxm_$uword_t;                   { 0x00 }
    tail: dxm_$uword_t;                   { 0x02 }
    mask: dxm_$uword_t;                   { 0x04 }
    pad_06: integer;                      { 0x06 }
    lock: integer32;                      { 0x08 }
    ec: ec_$eventcount_t;                 { 0x0C }
    entries: dxm_$entries_ptr_t;          { 0x18 }
  end;

  { The datum DXM_$ADD_SIGNAL queues, 10 bytes: routine 0x00, signal
    0x02, param 0x04, proc_index 0x08.  DXM_$ADD_SIGNAL stores the four
    fields and queues 10 bytes; DXM_$ADD_SIGNAL_CALLBACK reads them
    back: routine and proc_index as word indices, signal and param by
    address.  param is a status: the PEB interrupt queues the status
    16#00240002 (peb/m68k/int.s), and PROC2_$SIGNAL_PGROUP_OS takes it
    as a status_$t (proc2/proc2.ins.pas). }
  dxm_$signal_data_t = record
    routine: integer;                     { 0x00 }
    signal: integer;                      { 0x02 }
    param: status_$t;                     { 0x04 }
    proc_index: integer;                  { 0x08 }
  end;

  dxm_$signal_data_ptr_t = ^dxm_$signal_data_t;

  { A signal delivery routine, as DXM_$ADD_SIGNAL_CALLBACK calls one:
    four arguments by address, a process UID, the signal, the parameter
    and a status, under the default convention.  The two routines its
    table holds (PROC2_$SIGNAL_OS, PROC2_$SIGNAL_PGROUP_OS) do not have
    one heading (proc2/proc2.ins.pas: PROC2_$SIGNAL_OS reads its first
    three through their slots, `in'; PROC2_$SIGNAL_PGROUP_OS copies them,
    value parameters), and the address of a routine assigned to a routine
    pointer must match its type exactly (ref p. 4-146), so the table
    holds univ_ptr and the call transfers an element to this type
    (dxm/add_signal_callback.pas).  The modes here are PROC2_$SIGNAL_OS's;
    the call cannot tell `in' from a value parameter. }
  dxm_$signal_routine_t = ^procedure(in uid: uid_$t; in signal: integer;
                                     in param: status_$t;
                                     out status: status_$t);

var
  { DXM_$OVERRUNS, DXM_$UNWIRED_Q and DXM_$WIRED_Q, map symbols in DXM's
    WIRED_DATA block (+0x600, +0x604, +0x620), defined in dxm/dxm.pas.
    Other units push the queues' addresses as absolutes: DXM_$UNWIRED_Q
    in TTY_$I_SIGNAL, KBD_$RCV, SUMA_$RCV, AST_$SAVE_CLOBBERED_UID and
    TIME_$Q_SCAN_QUEUE, which queues on DXM_$WIRED_Q too.  No other unit
    names DXM_$OVERRUNS (DXM_$ADD_CALLBACK reaches it through A5). }
  dxm_$overruns: extern integer32;
  dxm_$unwired_q: extern dxm_$queue_t;
  dxm_$wired_q: extern dxm_$queue_t;

{ Routine headings, in map order. }

{ DXM_$ADD_CALLBACK - queue a routine and a copy of its datum on a DXM
  queue. }
procedure dxm_$add_callback(var queue: dxm_$queue_t;
                            in callback: univ univ_ptr;
                            in data: univ dxm_$data_ptr_t;
                            data_size: dxm_$uword_t;
                            check_dup: boolean;
                            out status: status_$t);
  options(extern, val_param);

{ DXM_$SCAN_QUEUE - run every routine queued on a DXM queue. }
procedure dxm_$scan_queue(var queue: dxm_$queue_t); extern;

{ DXM_$HELPER_COMMON - the body of a DXM helper process: wait for the
  queue's eventcount, run the queue, forever. }
procedure dxm_$helper_common(var queue: dxm_$queue_t); extern;

{ DXM_$HELPER_WIRED - the wired DXM helper process.
  DXM_$HELPER_UNWIRED - the unwired DXM helper process. }
procedure dxm_$helper_wired; extern;
procedure dxm_$helper_unwired; extern;

{ DXM_$ADD_SIGNAL (dxm/add_signal.pas).  The body reads every argument
  straight from its slot: the first three as words, the fourth as a
  longword, the fifth as a byte pushed on, and the last as an address
  passed on to DXM_$ADD_CALLBACK's `out' status.  Values in word slots
  and a byte in the high half of its word: `val_param' (ref 5.2, Table
  5-1).  Its one caller is hand assembly, PEB_$INT (peb/m68k/int.s, in
  the map's PEB_ASM data segment), whose pushes agree slot for slot: the
  status (a zero cell of its own literal pool) by address, check_dup the
  byte 16#FF, param the status 16#00240002, signal the word 8,
  proc_index the owner ASID byte zero-extended to a word, routine the
  word 0: 16 bytes, no pad.  Nothing else in the image calls it. }
procedure dxm_$add_signal(routine: integer; proc_index: integer;
                          signal: integer; param: status_$t;
                          check_dup: boolean; out status: status_$t);
  options(extern, val_param);

{ DXM_$INIT - set up the two DXM queues' eventcounts. }
procedure dxm_$init; extern;

{ DXM_$ADD_SIGNAL_CALLBACK - deliver a signal queued by DXM_$ADD_SIGNAL. }
procedure dxm_$add_signal_callback(in data: dxm_$signal_data_ptr_t);
  extern;
