{ PROC1_$VT_INT - fold the virtual timer into the current process's CPU
  time.

  Image addresses:
    sau2  0x00E1491E  PROC1_$VT_INT

  - The virtual timer word is added to the CPU clock and cleared; the
    CPU clock is returned.

  Status stored: none.
}

procedure proc1_$vt_int(out vt: time_$clock_t);
var
  delta: time_$clock_t;
  pcb: proc1_$pcb_ptr_t;
begin
  pcb := proc1_$current_pcb;
  delta.high := 0;
  delta.low := pcb^.vtimer;
  add48(pcb^.cpu.total, delta);
  pcb^.vtimer := 0;
  vt := pcb^.cpu.total;
end;
