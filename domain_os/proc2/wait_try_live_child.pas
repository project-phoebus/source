{ proc2_$wait_try_live_child - report one child of the waiter's child
  list, if it can be reported.

  Image addresses:
    sau2  0x00E3FC5C  proc2_$wait_try_live_child (module-local)

  Assume we're called with ml_$proc2_lock held.

  - A stopped child not yet reported is reported once (its stop status)
    when asked for; a dead child the waiter debugs, or no one does, is
    reaped.  found tells whether the result and pid were filled in.

  Status stored: none.
}

procedure proc2_$wait_try_live_child(child_idx: integer;
                                     options: proc2_$wait_options_t;
                                     parent_idx: integer;
                                     prev_sibling: integer;
                                     out found: boolean;
                                     out result: proc2_$wait_result_t;
                                     out pid_ret: integer); internal;
begin
  found := false;
  with proc2_$info_table[child_idx] do
    if (proc2_pf_stopped in flags.bits)
       and then not (xpd_pf_state_saved in flags.bits)
       and then (proc2_$wait_untraced in options) then begin

      flags.bits := flags.bits + [xpd_pf_state_saved];
      result.exit.status :=
        lshft(pad_94, 8) ! proc2_$wait_stopped;
      pid_ret := upid;
      found := true;
    end
    else if ((debugger_idx = 0)
             or else (debugger_idx =
                      proc2_$info_table[parent_idx].self_index))

            and then (proc2_pf_zombie in flags.bits) then begin

      proc2_$wait_reap_child(child_idx, parent_idx, prev_sibling,
                             result, pid_ret);
      found := true;
    end;
end;
