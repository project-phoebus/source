{ PROC2_$SIGRETURN - return from a user signal handler.

  Image addresses:
    sau2  0x00E3F582  PROC2_$SIGRETURN

  - The sigcontext's signal stack flag and blocked set go back into the
    entry under ml_$proc2_lock, what that unblocks is delivered, and the
    interrupted code is resumed through FIM_$FAULT_RETURN, which does not
    return.

  Status stored: none.
}

procedure proc2_$sigreturn(in context: univ_ptr;
                           in regs: univ_ptr;
                           in fp_state: univ_ptr;
                           out result: proc2_$sig_state_t);
var
  onstack: integer32;
  new_mask: proc2_$sig_set_t;
  idx: integer;
begin
  with fim_$sigcontext_ptr_t(context)^ do begin
    onstack := sc_onstack;
    new_mask := sc_mask;
  end;
  idx := proc2_$pid_to_index[proc1_$current];
  with proc2_$info_table[idx] do begin
    ml_$lock(ml_$proc2_lock);
    flags.on_sig_stack := onstack <> 0;
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
  fim_$fault_return(context, regs, fp_state);
end;
