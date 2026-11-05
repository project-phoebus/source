{ PROC1_$TS_END_CALLBACK - a process's timeslice has run out.

  Image addresses:
    sau2  0x00E14A70  PROC1_$TS_END_CALLBACK
    sau4  0x0F8152E4  PROC1_$TS_END_CALLBACK
    sau6  0x78015220  PROC1_$TS_END_CALLBACK
    sau7  0x3C416778  PROC1_$TS_END_CALLBACK

  - The timeslice element's callback; its datum is the pid.
  - With interrupts off, the null process (pid 2) gets the timeslice -1;
    another's state drops by one, not below its minimum, and its next
    timeslice is PROC1_$TSVV's for the new state.
  - A process holding resource locks keeps its place in the ready list
    and is marked boosted; another goes to the back of its state.

  Status stored: none.
}

procedure proc1_$ts_end_callback(in elem: univ_ptr);
var
  ts: integer;
  pid: pinteger;
  pcb: proc1_$pcb_ptr_t;
  old_sr: integer;
begin
  pid := proc1_$ts_view_ptr_t(elem)^.pid;
  pcb := pcbs[pid];
  old_sr := set_sr(16#2700);

  with pcb^ do
    if pid = 2 then
      ts := -1
    else begin
      cpu.state := cpu.state - 1;
      if pcb^.inh_count > cpu.state then
        cpu.state := pcb^.inh_count;
      if pcb^.resource_locks_word <> 0 then begin
        proc1_$reorder_ready(pcb^);
        pcb^.flags := pcb^.flags + [proc1_flag_boosted];
      end
      else begin
        proc1_$remove_ready(pcb^);
        proc1_$add_ready(pcb^);
      end;
      ts := proc1_$tsvv[cpu.state];
    end;

  discard(set_sr(old_sr));
  proc1_$set_ts(pcb, ts);
end;
