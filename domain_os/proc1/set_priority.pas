{ PROC1_$SET_PRIORITY - set or read a process's priority range.

  Image addresses:
    sau2  0x00E1523C  PROC1_$SET_PRIORITY

  - An invalid pid crashes the system.
  - set_it stores the clamped range; with interrupts off the state is
    moved into it, and a ready process reordered and the dispatcher run.
    Else the range is returned.

  Status stored: none.
}

procedure proc1_$set_priority(pid: pinteger; set_it: boolean;
                              var min_priority: integer;
                              var max_priority: integer);
var
  pcb: proc1_$pcb_ptr_t;
begin
  if (pid = 0) or else (pid > 64) then
    crash_system(status_$illegal_process_id);

  pcb := pcbs[pid];
  if set_it then begin
    pcb^.inh_count := proc1_$clamp_priority(min_priority);
    pcb^.sw_bsr := proc1_$clamp_priority(max_priority);
    disable;
    if pcb^.sw_bsr < pcb^.cpu.state then
      pcb^.cpu.state := pcb^.sw_bsr
    else if pcb^.inh_count > pcb^.cpu.state then
      pcb^.cpu.state := pcb^.inh_count;
    if pcb^.flags * [proc1_flag_waiting, proc1_flag_suspended,
                     proc1_flag_bound] = [proc1_flag_bound] then begin
      proc1_$reorder_ready(pcb^);
      proc1_$dispatch;
    end;
    enable;
  end
  else begin
    min_priority := pcb^.inh_count;
    max_priority := pcb^.sw_bsr;
  end;
end;
