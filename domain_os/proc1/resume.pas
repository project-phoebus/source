{ PROC1_$RESUME - resume a suspended process.

  Image addresses:
    sau2  0x00E1476E  PROC1_$RESUME
    sau4  0x0F814FE2  PROC1_$RESUME
    sau6  0x78014F32  PROC1_$RESUME
    sau7  0x3C41648A  PROC1_$RESUME

  - With interrupts off, a suspended process goes back on the ready
    list unless it waits on an eventcount, and the dispatcher runs; a
    process only marked for suspension loses the mark.

  Status stored:
    status_$ok: the process was resumed, or its mark cleared
    status_$illegal_process_id: pid is not 1..64
    status_$process_not_bound: its PCB is not bound
    status_$process_not_suspended: neither suspended nor marked
}

procedure proc1_$resume(pid: pinteger; out status_p: status_$t);
var
  pcb: proc1_$pcb_ptr_t;
begin
  if (pid = 0) or else (pid > 64) then begin
    status_p.all := status_$illegal_process_id;
    return;
  end;

  pcb := pcbs[pid];
  if not (proc1_flag_bound in pcb^.flags) then begin
    status_p.all := status_$process_not_bound;
    return;
  end;

  status_p.all := status_$ok;
  disable;
  if proc1_flag_suspended in pcb^.flags then begin
    pcb^.flags := pcb^.flags - [proc1_flag_suspended];
    if not (proc1_flag_waiting in pcb^.flags) then
      proc1_$add_ready(pcb^);
    proc1_$dispatch;
  end
  else begin
    if proc1_flag_defer_susp in pcb^.flags then
      pcb^.flags := pcb^.flags - [proc1_flag_defer_susp]
    else
      status_p.all := status_$process_not_suspended;
    enable;
  end;
end;
