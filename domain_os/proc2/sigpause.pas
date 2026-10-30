{ PROC2_$SIGPAUSE - install a temporary blocked set and wait for a
  signal.

  Image addresses:
    sau2  0x00E3FA10  PROC2_$SIGPAUSE

  - Under ml_$proc2_lock the blocked set is saved (+0x88, flags member
    14) and the new one installed and handed back; then the quit
    eventcount is waited on until a signal is pending and not blocked,
    and the pending signals are delivered.

  Status stored: none.
}

procedure proc2_$sigpause(in new_mask: proc2_$sig_set_t;
                          out result: proc2_$sig_state_t);
var
  ecs: ec_$waitn_ecs_t;
  wait_val: ec_$waitn_vals_t;
  mask: proc2_$sig_set_t;
  idx: integer;
  entry: proc2_info_ptr_t;
begin
  mask := new_mask;
  idx := proc2_$pid_to_index[proc1_$current];
  entry := addr(proc2_$info_table[idx]);
  ml_$lock(ml_$proc2_lock);
  with entry^ do begin
    pad_88 := integer32(sig_blocked.blocked_2);
    sig_blocked.blocked_2 := mask;
    flags.bits := flags.bits + [proc2_pf_mask_saved];
    ml_$unlock(ml_$proc2_lock);
    result.blocked := sig_blocked.blocked_2;
    if proc2_pf_on_sig_stack in flags.bits then
      result.on_sigstack := 1
    else
      result.on_sigstack := 0;
    ecs[1] := addr(fim_$quit_ec[proc1_$as_id]);
    repeat
      wait_val[1] := fim_$quit_value[proc1_$as_id] + 1;
      if sig_mask_2 - sig_blocked.blocked_2 <> [] then begin

        ml_$lock(ml_$proc2_lock);
        proc2_$deliver_pending_internal(self_index);
        ml_$unlock(ml_$proc2_lock);
        return;
      end;
      discard(ec_$waitn(ecs, wait_val, 1));
      fim_$quit_value[proc1_$as_id] :=
        fim_$quit_ec[proc1_$as_id].value;
    until false;
  end;
end;
