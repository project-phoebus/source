{ PROC1_$SET_VT - set a process's virtual timer.

  Image addresses:
    sau2  0x00E1495C  PROC1_$SET_VT

  - The timer value is delay's low word, or -1 when its high longword is
    not zero.
  - For the current process, with interrupts off, the time the hardware
    timer has run is folded into the CPU clock and the timer written;
    for another the value is only stored.

  Status stored:
    status_$illegal_process_id: pid is not 1..64
    status_$process_not_bound: its PCB is not bound
    none: the timer was set
}

procedure proc1_$set_vt(pid: pinteger; in delay: time_$clock_t;
                        out status: status_$t);
var
  d: time_$clock_t;
  pcb: proc1_$pcb_ptr_t;
  vt: integer;
  old_sr: integer;
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

  if delay.high <> 0 then
    vt := -1
  else
    vt := delay.low;

  if pcb = proc1_$current_pcb then begin
    old_sr := set_sr(16#2700);
    d.high := 0;
    d.low := pcb^.vtimer - time_$vt_timer;
    add48(pcb^.cpu.total, d);
    pcb^.vtimer := vt;
    time_$wrt_timer(2, pcb^.vtimer);
    discard(set_sr(old_sr));
  end
  else
    pcb^.vtimer := vt;
end;
