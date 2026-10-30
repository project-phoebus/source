{ PROC2_$SET_SIG_MASK - change the current process's signal state.

  Image addresses:
    sau2  0x00E3F7DE  PROC2_$SET_SIG_MASK

  - Under ml_$proc2_lock each signal set loses the clear record's members
    and gains the set record's; the two flags follow the records'
    booleans.
  - The priority delta detaches children past a lowered value.
  - A pending or blocked SIGCLD detaches matching zombie children or is
    posted; then what is unblocked is delivered and the blocked set and
    signal stack flag handed back.

  Status stored: none.
}

procedure proc2_$set_sig_mask(in priority_delta: integer;
                              clear_mask: proc2_$sig_mask_t;
                              set_mask: proc2_$sig_mask_t;
                              out result: proc2_$sig_state_t);
var
  delta: integer;
  prev: integer;
  index: integer;
  child_idx: integer;
  next: integer;
begin
  delta := priority_delta;
  index := proc2_$pid_to_index[proc1_$current];
  ml_$lock(ml_$proc2_lock);
  with proc2_$info_table[index] do begin
    sig_blocked.blocked_1 := (sig_blocked.blocked_1
                              - clear_mask.blocked.blocked_1)
                             + set_mask.blocked.blocked_1;
    sig_blocked.blocked_2 := (sig_blocked.blocked_2
                              - clear_mask.blocked.blocked_2)
                             + set_mask.blocked.blocked_2;
    sig_pending := (sig_pending - clear_mask.pending)
                   + set_mask.pending;
    sig_mask_1 := (sig_mask_1 - clear_mask.mask_1)
                  + set_mask.mask_1;
    sig_mask_2 := sig_mask_2 - clear_mask.mask_2;
    sig_mask_3 := (sig_mask_3 - clear_mask.mask_3)
                  + set_mask.mask_3;
    if clear_mask.flag_1 then
      flags.bits := flags.bits - [10];
    if set_mask.flag_1 then
      flags.bits := flags.bits + [10];
    if clear_mask.mask_4 <> [] then
      sig_mask_4 := set_mask.mask_4;
    if clear_mask.flag_2 then
      flags.bits := flags.bits - [2];
    if set_mask.flag_2 then
      flags.bits := flags.bits + [2];
    if delta <> 0 then begin
      delta := delta + pad_18[1];
      if (delta < pad_18[1]) and then (delta > 0) then begin

        child_idx := first_child_idx;
        prev := 0;
        while child_idx <> 0 do
          with proc2_$info_table[child_idx]: child do
            if delta < child.pad_18[2] then begin
              next := child.next_child_sibling;
              proc2_$detach_from_parent(child_idx, prev);
              child_idx := next;
            end
            else begin
              prev := child_idx;
              child_idx := child.next_child_sibling;
            end;
      end;
      pad_18[1] := delta;
    end;
    if not ((proc2_$sig_cld - 1) in sig_mask_2)
       and then (((proc2_$sig_cld - 1) in sig_pending)
                 or else ((proc2_$sig_cld - 1)
                          in sig_blocked.blocked_1)) then begin

      child_idx := first_child_idx;
      prev := 0;
      while child_idx <> 0 do
        with proc2_$info_table[child_idx]: child do
          if (proc2_pf_zombie in child.flags.bits)
             and then (child.pad_18[2] = pad_18[1]) then
            if (proc2_$sig_cld - 1) in sig_blocked.blocked_1 then begin

              next := child.next_child_sibling;
              proc2_$detach_from_parent(child_idx, prev);
              child_idx := next;
            end
            else begin
              sig_mask_2 := sig_mask_2 + [proc2_$sig_cld - 1];

              exit;
            end
          else begin
            prev := child_idx;
            child_idx := child.next_child_sibling;
          end;
    end;
    if sig_mask_2 - sig_blocked.blocked_2 <> [] then
      proc2_$deliver_pending_internal(self_index);
    ml_$unlock(ml_$proc2_lock);
    result.blocked := sig_blocked.blocked_2;
    if 10 in flags.bits then
      result.on_sigstack := 1
    else
      result.on_sigstack := 0;
  end;
end;
