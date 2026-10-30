{ di/di.ins.pas - DI_ (the deferred-interrupt queue), for the Domain
  Pascal tree.

  What the Pascal files use.  DI_$ENQ and DI_$INIT_Q_ELEM are
  hand-written assembly inside the map's PROC1_ASM data segment
  (di/README.md; di/m68k/enq.s, di/m68k/init_q_elem.s), so these
  are only the type and the heading the compiled callers use, each from
  how they call.  Apollo's customer insert files of SR10.2 declare none
  of these.  Include base/base.ins.pas before it.
}

type
  { A deferred-interrupt queue element, 16 bytes: the link at 0, the
    routine at 4, its datum at 8, the enqueued flag at 0xC.
    DI_$INIT_Q_ELEM clears the four longwords; the timer handler hands
    DI_$ENQ the routine and its datum (time/m68k/timer_handler.s);
    PROC1_$INT_EXIT clears the flag and calls the routine with the datum
    pushed (proc1/m68k/int_handler.s).  arg1 is the routine, arg2 its
    datum. }
  di_$q_elem_t = record
    next: univ_ptr;                       { 0x00 }
    arg1: univ_ptr;                       { 0x04: the routine }
    arg2: univ_ptr;                       { 0x08: its datum }
    enqueued: boolean;                    { 0x0C }
    reserved_0d: char;                    { 0x0D }
    reserved_0e: char;                    { 0x0E }
    reserved_0f: char;  { 0x0F: (layout)
                                            three chars, not a 3-char
                                            array, which is word aligned
                                            in an unpacked record (ref
                                            3.10.5.5) and would make the
                                            record 0x12 bytes }
  end;

{ DI_$INIT_Q_ELEM (hand assembly, above): clears the element through its
  one argument, read off the stack, never reading it: `out', by address.
  Its compiled caller, TIME_$INIT, pushes the address of another unit's
  variable (TIME_$DI_VT, then TIME_$DI_RTE). }
procedure di_$init_q_elem(out elem: di_$q_elem_t); extern;

{ DI_$ENQ (hand assembly, above): queues an element for the end of the
  interrupt: the routine and its datum, longwords by value, and the
  element by address, read off the stack (`val_param').  Its compiled
  caller, the SAU9's ETHERNET_$INTERRUPT, pushes them so. }
procedure di_$enq(routine: univ_ptr; datum: univ_ptr;
                  var elem: di_$q_elem_t);
  options(extern, val_param);
