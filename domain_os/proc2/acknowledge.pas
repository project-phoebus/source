{ PROC2_$ACKNOWLEDGE - acknowledge a signal's delivery to the current
  process.

  Image addresses:
    sau2  0x00E3F338  PROC2_$ACKNOWLEDGE

  - Under ml_$proc2_lock: the new blocked set is installed, the signal
    cleared from sig_mask_2 and acknowledged to FIM; flag 10 notes a
    signal of sig_mask_3.
  - A stop signal kills the process (SIGKILL, no group leader) or stops
    it, telling the parent (SIGCHLD); the suspension takes effect at the
    lock's release, outside it.
  - Pending signals are delivered; the blocked set and flag 10 are
    handed back.

  Status stored: none.
}

procedure proc2_$acknowledge(in new_blocked: proc2_$sig_set_t;
                             in signal: integer;
                             out result: proc2_$sig_state_t);
var
  sig_m1: integer;
  deliver_param: status_$t;
  status: status_$t;
  sig_mask: proc2_$sig_set_t;
  was_set: boolean;
  idx: integer;
begin
  idx := proc2_$pid_to_index[proc1_$current];
  sig_m1 := signal - 1;
  sig_mask := [sig_m1];
  with proc2_$info_table[idx] do begin
    ml_$lock(ml_$proc2_lock);
    sig_blocked.blocked_2 := new_blocked;
    if sig_mask - sig_mask_2 = [] then begin
      sig_mask_2 := sig_mask_2 - sig_mask;
      was_set := true;
    end
    else
      was_set := false;
    if sig_mask - sig_mask_3 = [] then
      flags.bits := flags.bits + [10];
    fim_$acknowledge;
    if (sig_mask * proc2_$not_stop_signals = [])
       and then (sig_mask - sig_pending <> []) then
      if not was_set then
        sig_mask_2 := sig_mask_2 - [proc2_$sig_cont - 1]
      else if ((proc2_$pgroup_table[pgroup_table_idx].leader_count = 0)

               or else (15 in flags.bits)
               or else (pgroup_table_idx = 0))
              and then not ((proc2_$sig_stop - 1) in sig_mask) then begin

        deliver_param.all := status_$proc2_kill_fault;
        proc2_$deliver_signal_internal(self_index, proc2_$sig_kill,
                                       deliver_param, status);

      end
      else begin
        pad_94 := signal;
        flags.bits := flags.bits - [4, 5];
        flags.bits := flags.bits + [6];
        deliver_param.all := status_$proc2_child_changed_fault;

        if not (15 in flags.bits) then begin
          ec_$advance(proc2_$ec[parent_pgroup_idx].cr_rec_ec);

          if not (2 in proc2_$info_table[parent_pgroup_idx].flags.bits) then

            proc2_$deliver_signal_internal(parent_pgroup_idx,
                                           proc2_$sig_chld, deliver_param,
                                           status);
        end;
        discard(proc1_$suspend(level1_pid, status));
        ml_$unlock(ml_$proc2_lock);
        ml_$lock(ml_$proc2_lock);
      end;
    if sig_mask - sig_mask_1 = [] then
      sig_pending := sig_pending - sig_mask;
    proc2_$deliver_pending_internal(self_index);
    ml_$unlock(ml_$proc2_lock);
    result.blocked := sig_blocked.blocked_2;
    if 10 in flags.bits then
      result.on_sigstack := 1
    else
      result.on_sigstack := 0;
  end;
end;
