{ PROC2_$SIGSETMASK - replace the current process's blocked set.

  Image addresses:
    sau2  0x00E3F6C0  PROC2_$SIGSETMASK

  - Under ml_$proc2_lock the set becomes the blocked set and what that
    unblocks is delivered; the result is the blocked set before the call
    (4.3BSD's sigsetmask).

  Status stored: none.
}

function proc2_$sigsetmask(in mask: proc2_$sig_set_t;
                           out result: proc2_$sig_state_t):
  proc2_$sig_set_t;
var
  new_mask: proc2_$sig_set_t;
  old_mask: proc2_$sig_set_t;
  idx: integer;
begin
  new_mask := mask;
  idx := proc2_$pid_to_index[proc1_$current];
  with proc2_$info_table[idx] do begin
    ml_$lock(ml_$proc2_lock);
    old_mask := sig_blocked.blocked_2;
    sig_blocked.blocked_2 := new_mask;
    if sig_mask_2 - sig_blocked.blocked_2 <> [] then
      proc2_$deliver_pending_internal(self_index);
    ml_$unlock(ml_$proc2_lock);
    result.blocked := sig_blocked.blocked_2;
    if 10 in flags.bits then
      result.on_sigstack := 1
    else
      result.on_sigstack := 0;
  end;
  proc2_$sigsetmask := old_mask;
end;
