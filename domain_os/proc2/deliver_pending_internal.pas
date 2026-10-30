{ proc2_$deliver_pending_internal - hand a process's next pending signal
  to FIM.

  Image addresses:
    sau2  0x00E3ECEA  proc2_$deliver_pending_internal (module-local)

  - The next deliverable signal (proc2_$get_next_pending_signal), unless
    quits are inhibited and it is neither the debugger's SIGKILL nor a
    BLAST SIGAPOLLO: the address space's trace status is set, quits
    inhibited, a trace fault delivered and the quit eventcount advanced.

  Status stored: none.
}

procedure proc2_$deliver_pending_internal(proc_index: integer);
var
  signal: integer;
begin
  with proc2_$info_table[proc_index] do begin
    signal := proc2_$get_next_pending_signal(
                proc2_$info_table[proc_index]);
    if signal = 0 then
      return;
    if fim_$quit_inh[asid]
       and then not (((signal = proc2_$sig_kill)
                      and then (debugger_idx =
                                proc2_$pid_to_index[proc1_$current]))
                     or else ((signal = proc2_$sig_apollo)
                              and then (sig_status = fault_$blast))) then
      return;
    if signal = proc2_$sig_apollo then
      fim_$trace_sts[asid].all := sig_status
    else
      fim_$trace_sts[asid].all := 0;
    fim_$trace_sts[asid].signal_flag := 1;
    fim_$quit_inh[asid] := true;
    fim_$deliver_trace_fault(asid);
    ec_$advance(fim_$quit_ec[asid]);
  end;
end;
