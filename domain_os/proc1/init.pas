{ PROC1_$INIT - initialize the level-1 process manager.

  Image addresses:
    sau2  0x00E2F958  PROC1_$INIT
    sau4  0x0F832E50  PROC1_$INIT
    sau6  0x78038278  PROC1_$INIT
    sau7  0x3C437E50  PROC1_$INIT

  - The stack allocator's regions run from OS_STACK up and from
    OS_STACK_END down; the system process's OS stack base is
    P1_STACK_BASE.  The three are the map's symbols' addresses.
  - The system process (PCB 1) becomes the current process and the
    null process (pid 2) gets type 3; the dispatcher then runs, and sets
    the priority.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure proc1_$init;
begin
  proc1_$stack_low_water := integer32(addr(os_stack));
  proc1_$stack_high_water := integer32(addr(os_stack_end));
  proc1_$stack_free_list := 0;
  os_stack_base[1] := integer32(addr(p1_stack_base));
  proc1_$set_type(2, 3);

  with pcbs[1]^ do begin
    cpu.state := 16;
    inh_count := 1;
    sw_bsr := 16;
    resource_locks_word := 0;
    disable;
    if flags * [proc1_flag_waiting, proc1_flag_suspended,
                proc1_flag_bound] = [proc1_flag_bound] then
      proc1_$reorder_ready(pcbs[1]^)
    else begin
      flags := [proc1_flag_bound];
      proc1_$add_ready(pcbs[1]^);
    end;
  end;

  proc1_$current_pcb := pcbs[1];
  proc1_$current := proc1_$current_pcb^.mypid;
  proc1_$init_ts_timer(2);
  proc1_$init_ts_timer(1);
  proc1_$dispatch;
  pmap_$init_ws_scan(2, 5);
  pmap_$init_ws_scan(1, 7);
end;
