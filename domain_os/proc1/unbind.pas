{ PROC1_$UNBIND - unbind a process from its PCB.

  Image addresses:
    sau2  0x00E14E24  PROC1_$UNBIND
    sau4  0x0F815698  PROC1_$UNBIND

  - The current process suspends itself with interrupts off; it must end
    up suspended, else the system crashes.  Another process is first
    suspended, and waited for, if it is not.
  - The process's virtual-timer queue is flushed, its stack freed and
    its type cleared; the dispatcher then runs, and sets the priority.

  Status stored:
    status_$illegal_process_id: pid is not 1..64
    status_$process_not_bound: its PCB is not bound
    proc1_$suspend's or proc1_$suspendp's status: another process was
      suspended first
    none: the process was the current one, or suspended already
}

procedure proc1_$unbind(pid: pinteger; out status: status_$t);
var
  pcb: proc1_$pcb_ptr_t;
  ec_value: integer32;
  wait_value: integer32;
  suspended: boolean;
begin
  if (pid = 0) or else (pid > 64) then begin
    status.all := status_$illegal_process_id;
    return;
  end;

  pcb := pcbs[pid];
  if not (proc1_flag_bound in pcb^.flags) then begin
    status.all := status_$process_not_bound;
    return;
  end;

  if pcb = proc1_$current_pcb then begin
    pmap_$purge_ws(pid, false);
    disable;
    proc1_$try_to_suspend(pcb^);
    if not (proc1_flag_suspended in pcb^.flags) then
      crash_system(status_$process_not_suspendable);
  end
  else begin
    if not (proc1_flag_suspended in pcb^.flags) then begin
      ec_value := proc1_$suspend_ec.value;
      suspended := proc1_$suspend(pid, status);
      wait_value := ec_value + 1;
      while not suspended do begin
        discard(ec_$wait(addr(proc1_$suspend_ec), addr(ec_$nil_ec),
                         addr(ec_$nil_ec), wait_value, 0, 0));
        suspended := proc1_$suspendp(pid, status);
      end;
    end;
    pmap_$purge_ws(pid, false);
    disable;
  end;

  time_$q_flush_queue(time_$vtq[pid]);
  pcb^.flags := pcb^.flags - [proc1_flag_bound];
  proc1_$free_stack(os_stack_base[pid]);
  proc1_$set_type(pid, 0);
  proc1_$dispatch;
end;
