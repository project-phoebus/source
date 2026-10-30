{ proc2_$wait_try_zombie - report one process of the waiter's debug
  target list, if it can be reported.

  Image addresses:
    sau2  0x00E3FD06  proc2_$wait_try_zombie (module-local)

  Assume we're called with ml_$proc2_lock held.

  - A dead target is reaped if the init process, else its debugging ends
    and its exit report goes back with a nil parent; a suspended target is
    reported once.  The options word is never read.

  Status stored: none.
}

procedure proc2_$wait_try_zombie(child_idx: integer;
                                 options: proc2_$wait_options_t;
                                 out found: boolean;
                                 out result: proc2_$wait_result_t;
                                 out pid_ret: integer); internal;
begin
  found := false;
  with proc2_$info_table[child_idx] do
    if proc2_pf_zombie in flags.bits then begin
      if proc2_pf_init in flags.bits then
        proc2_$wait_reap_child(child_idx, 0, 0, result,
                               pid_ret)
      else begin
        debug_clear_internal(self_index, false);
        result.exit := zombie_exit;
        result.parent_uid := uid_$nil;
        pid_ret := upid;
      end;
      found := true;
    end
    else if (xpd_pf_suspended in flags.bits)
            and then not (xpd_pf_state_saved in flags.bits) then begin

      flags.bits := flags.bits + [xpd_pf_state_saved];
      result.exit.status :=
        lshft(pad_94, 8) ! proc2_$wait_stopped;
      result.exit.info := fault_param;
      result.exit.info.signal_flag := false;
      if fault_param.signal_flag then
        result.flag_64 := true;
      result.child_uid := uid;
      pid_ret := upid;
      found := true;
    end;
end;
