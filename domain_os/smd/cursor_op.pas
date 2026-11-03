{ smd_$cursor_op - draw or clear one of the display's cursors.

  Image addresses:
    sau2  0x00E6DFFA  smd_$cursor_op (module-local)
    sau4  0x0F87877C  smd_$cursor_op (module-local)
    sau5  0x00E70458  smd_$cursor_op (module-local)

  - The hand-written SMD_$XOR_CURSOR draws the cursor (clear_flag false)
    or removes it (true), with the display acquired.

  Status stored:
    status_$ok: the cursor was drawn or removed
    smd_$illegal_caller: the process has no display unit
    smd_$invalid_crsr_number: cursor_num is not 0..3
}

{ TODO(pascal) frame of smd_$cursor_op not accounted

  The module-local's reserved slot, unit (2) and hw (4) take 12 bytes
  rounded; 4 bytes of the image's 16 are left, which a `with
  smd_$wired_data.unit[unit]' slot (its address kept in a register,
  never stored) would fill.  As in the other SMD frames, whether such a
  `with' has a slot is not settled. }

procedure smd_$cursor_op(cursor_num: integer; pos: smd_$pos_t;
                         clear_flag: boolean; out status: status_$t);
  internal;
var
  unit: integer;
  hw: smd_display_hw_ptr_t;
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;

  if (cursor_num < 0) or (cursor_num > 3) then begin
    status.all := smd_$invalid_crsr_number;
    return;
  end;

  hw := smd_$wired_data.unit[unit].hw;
  discard(smd_$acq_display(1));
  discard(smd_$xor_cursor(cursor_num, pos, hw^.disp_limits, hw^,
                          clear_flag,
                          smd_$wired_data.unit[unit].display_base,
                          smd_$wired_data.unit[unit].ctrl_regs));
  smd_$rel_display;
  status.all := status_$ok;
end;
