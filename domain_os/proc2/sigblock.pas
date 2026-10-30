{ PROC2_$SIGBLOCK - add signals to the current process's blocked set.

  Image addresses:
    sau2  0x00E3F63E  PROC2_$SIGBLOCK

  - Under ml_$proc2_lock the set joins the blocked set; the blocked set
    and the signal stack flag are handed back, and the result is the
    blocked set before the call (4.3BSD's sigblock).

  Status stored: none.
}

function proc2_$sigblock(in mask: proc2_$sig_set_t;
                         out result: proc2_$sig_state_t): proc2_$sig_set_t;
var
  new_bits: proc2_$sig_set_t;
  old_mask: proc2_$sig_set_t;
  idx: integer;
begin
  new_bits := mask;
  idx := proc2_$pid_to_index[proc1_$current];
  with proc2_$info_table[idx] do begin
    ml_$lock(ml_$proc2_lock);
    old_mask := sig_blocked.blocked_2;
    sig_blocked.blocked_2 := sig_blocked.blocked_2 + new_bits;
    ml_$unlock(ml_$proc2_lock);
    result.blocked := sig_blocked.blocked_2;
    if 10 in flags.bits then
      result.on_sigstack := 1
    else
      result.on_sigstack := 0;
  end;
  proc2_$sigblock := old_mask;
end;
