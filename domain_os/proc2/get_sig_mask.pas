{ PROC2_$GET_SIG_MASK - return the current process's signal state.

  Image addresses:
    sau2  0x00E3F75A  PROC2_$GET_SIG_MASK
    sau9  0x3C446C0C  PROC2_$GET_SIG_MASK

  - The blocked, pending and four other signal sets, the signal stack
    and no-SIGCHLD-on-stop flags; no lock is taken.

  Status stored: none.
}

procedure proc2_$get_sig_mask(out mask_ret: proc2_$sig_mask_t);
var
  idx: integer;
begin
  idx := proc2_$pid_to_index[proc1_$current];
  with proc2_$info_table[idx] do begin
    mask_ret.blocked := sig_blocked;
    mask_ret.pending := sig_pending;
    mask_ret.mask_1 := sig_mask_1;
    mask_ret.mask_2 := sig_mask_2;
    mask_ret.mask_3 := sig_mask_3;
    mask_ret.mask_4 := sig_mask_4;
    mask_ret.flag_1 := 10 in flags.bits;
    mask_ret.flag_2 := 2 in flags.bits;
  end;
end;
