{ XPD_$RESTART - resume a stopped target.

  Image addresses:
    sau2  0x00E5B54A  XPD_$RESTART

  - The target (XPD_$FIND_INDEX, under the process-table lock) must
    have a published debug state.  A PC other than 1 replaces the fault
    frame's.
  - Modes 1..3 clear the suspended flag, set or clear the single-step
    one, and resume the target.
  - With flags2 member 4 it waits until the target has stopped again or
    is no longer a debug target, and reports how.

  Status stored:
    status_$ok: resumed (or mode 0)
    the target's fault status, or 16#09010000 plus the signal: it
      stopped again
    proc2_$uid_not_found: it is no longer a debug target
    status_$xpd_state_unavailable_for_this_event: none published
    XPD_$FIND_INDEX's or PROC1_$RESUME's status: those failed
}

procedure xpd_$restart(proc_uid: uid_$t; in mode: pinteger; in pc: linteger;
                       in signal: integer; in status: status_$t;
                       out status_ret: status_$t);
label
  10;
var
  wait_val: integer32;
  st: status_$t;
  index: integer;
  state: xpd_$debug_state_ptr_t;
  ecs: xpd_$ec_list_t;
begin
  ml_$lock(ml_$proc2_lock);
  index := xpd_$find_index(proc_uid, st);
  ml_$unlock(ml_$proc2_lock);
  if st.all = status_$ok then
    with proc2_$info_table[index] do begin
      state := state_va;
      if state = nil then begin
        status_ret.all := status_$xpd_state_unavailable_for_this_event;
        return;
      end;

      if pc <> 1 then
        state^.frame^.pc := pc;

      if (pad_94 <> signal) or else
         ((pad_94 = 16#13) and then (status.all <> 0)) then begin
        fault_param.all := status.all;
        fault_param.signal_flag := true;
      end;
      pad_94 := signal;

      case mode of
        xpd_$restart_mode_no_resume: begin
          goto 10;
        end;
        xpd_$restart_mode_continue: begin
          flags.bits := flags.bits - [xpd_pf_trace_pending, xpd_pf_suspended];
          proc1_$resume(level1_pid, st);
        end;
        xpd_$restart_mode_step: begin
          flags.bits := flags.bits + [xpd_pf_trace_pending];
          flags.bits := flags.bits - [xpd_pf_suspended];
          proc1_$resume(level1_pid, st);
        end;
        xpd_$restart_mode_step_no_trace: begin
          flags.bits := flags.bits - [xpd_pf_suspended];
          proc1_$resume(level1_pid, st);
        end;
      end;

      if 4 in ptrace_opts.flags2 then begin
        wait_val := ec_$read(proc2_$ec[debugger_idx].cr_rec_ec) + 1;
        while not (xpd_pf_suspended in flags.bits) and then
              (xpd_pf_debug_target in flags.bits) do begin
          ecs[1] := addr(proc2_$ec[debugger_idx].cr_rec_ec);
          discard(ec_$waitn(ecs, wait_val, 1));
          wait_val := ec_$read(proc2_$ec[debugger_idx].cr_rec_ec) + 1;
        end;
        if xpd_pf_debug_target in flags.bits then begin
          flags.bits := flags.bits + [xpd_pf_state_saved];
          if fault_param.all <> 0 then
            st.all := fault_param.all
          else
            st.all := pad_94 + xpd_signal_status_base;
        end
        else
          st.all := proc2_$uid_not_found;
      end;
    end;

10:
  status_ret := st;
end;
