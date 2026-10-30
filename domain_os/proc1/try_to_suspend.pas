{ PROC1_$TRY_TO_SUSPEND - suspend a process now, or mark it for later.

  Image addresses:
    sau2  0x00E1471C  PROC1_$TRY_TO_SUSPEND

  Assume we're called with interrupts off.

  - A process inside an inhibited region stays marked, and
    PROC1_$INHIBIT_END suspends it later.
  - PROC1_$SUSPEND_EC is advanced without a dispatch.

  Status stored: none.
}

procedure proc1_$try_to_suspend(var pcb: proc1_$pcb_t);
begin
  pcb.flags := pcb.flags + [proc1_flag_defer_susp];
  if proc1_$inhibit_check(addr(pcb)) then
    return;

  if not (proc1_flag_waiting in pcb.flags) then
    proc1_$remove_ready(pcb);

  pcb.flags := pcb.flags - [proc1_flag_defer_susp] + [proc1_flag_suspended];
  advance(proc1_$suspend_ec);
end;
