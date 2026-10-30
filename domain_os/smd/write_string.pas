{ SMD_$WRITE_STRING - write a string on the display, clipped to the
  display's limits.

  Image addresses:
    sau2  0x00E6FEBE  SMD_$WRITE_STRING
    sau5  0x00E723EA  SMD_$WRITE_STRING

  - The clip window is set to the display's whole limits for the write
    (SMD_$WRITE_STR_CLIP, in SMD_UTILS) and restored after it.
  - The heading is Apollo's smd_$write_string_u (smdu.ins.pas of
    SR10.2), but pos and str_len are value parameters.
  - A procedure, D0 left as the call left it.

  Status stored:
    smd_$write_str_clip's status: the string was written, or not
    smd_$illegal_caller: the process has no display unit
}

{ TODO(pascal) the order of SMD_$WRITE_STRING's frame objects

  The image's frame has 0x14 bytes: saved_clip at the top, then pos's
  copy, str_len's, and 4 bytes that nothing addresses.  dpc's layout
  (`--dump-locals') gives the source above the same 20 bytes, but in
  another order: the copies first, from the top, in parameter order,
  then unit (a slot the image does not use: unit is held in a register)
  and saved_clip (the image's order here is the local above the copies,
  as in FILE_$INVALIDATE's).  The order is not settled. }

procedure smd_$write_string(pos: smd_$pos_t; in font_id: pinteger;
                            in str: univ smd_$string_t;
                            str_len: pinteger; in scroll_wait: boolean;
                            out status: status_$t);
var
  unit: integer;
  saved_clip: smd_$window_limits_t;
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;

  with smd_$display_com[unit] do begin
    saved_clip := clip_window;
    clip_window := disp_limits;
    discard(smd_$write_str_clip(pos, font_id, str, str_len,
                                scroll_wait, status));
    clip_window := saved_clip;
  end;
end;
