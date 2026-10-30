{ PROC2_$DELIVER_PENDING - deliver the current process's pending
  signals.

  Image addresses:
    sau2  0x00E3F520  PROC2_$DELIVER_PENDING

  - Under ml_$proc2_lock quit faults are let through again
    (FIM_$QUIT_INH) and proc2_$deliver_pending_internal runs.

  Status stored: none.
}

procedure proc2_$deliver_pending;
var
  current_idx: integer;
begin
  current_idx := proc2_$pid_to_index[proc1_$current];
  ml_$lock(ml_$proc2_lock);
  fim_$quit_inh[proc1_$as_id] := false;
  proc2_$deliver_pending_internal(current_idx);
  ml_$unlock(ml_$proc2_lock);
end;
