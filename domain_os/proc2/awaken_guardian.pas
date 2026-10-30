{ PROC2_$AWAKEN_GUARDIAN - wake a process's guardian (its debugger, or
  else its parent).

  Image addresses:
    sau2  0x00E3E960  PROC2_$AWAKEN_GUARDIAN

  - Flag 5 is cleared, the guardian sent SIGCLD and SIGCHLD and its
    creation-record eventcount advanced; a guardian that is not the
    debugger also gets the fork eventcount advanced, twice if still 0.

  Status stored: none.
}

procedure proc2_$awaken_guardian(in proc_index: pinteger);
var
  status: status_$t;
  param: status_$t;
  guardian: integer;
begin
  with proc2_$info_table[proc_index] do begin
    if debugger_idx <> 0 then
      guardian := debugger_idx
    else
      guardian := parent_pgroup_idx;
    flags.bits := flags.bits - [5];
    if guardian <> 0 then begin
      param.all := 0;
      proc2_$deliver_signal_internal(guardian, proc2_$sig_cld, param,
                                     status);
      proc2_$deliver_signal_internal(guardian, proc2_$sig_chld, param,
                                     status);
      ec_$advance(proc2_$ec[guardian].cr_rec_ec);
    end;
    if guardian <> debugger_idx then
      with proc2_$ec[self_index] do begin
        ec_$advance(fork_ec);
        if fork_ec.value = 0 then
          ec_$advance(fork_ec);
      end;
  end;
end;
