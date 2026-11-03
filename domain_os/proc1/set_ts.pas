{ PROC1_$SET_TS - re-arm a process's timeslice timer.

  Image addresses:
    sau2  0x00E14A08  PROC1_$SET_TS
    sau4  0x0F81527C  PROC1_$SET_TS

  - The element expires timeslice ticks of the process's own CPU time
    from now.  TIME_$Q_REENTER_ELEM's status is ignored.

  Status stored: none.
}

procedure proc1_$set_ts(pcb: proc1_$pcb_ptr_t; timeslice: integer);
var
  status: status_$t;
  when: time_$clock_t;
begin
  when.high := 0;
  when.low := timeslice;
  time_$q_reenter_elem(time_$vtq[pcb^.mypid], when, time_$relative,
                       pcb^.cpu.total, proc1_$ts_elem[pcb^.mypid].elem,
                       status);
end;
