{ SMD_$DEL_TRK_RECT - remove rectangles from the tracking list.

  Image addresses:
    sau2  0x00E6E614  SMD_$DEL_TRK_RECT
    sau5  0x00E70A96  SMD_$DEL_TRK_RECT
    sau9  0x3C47501C  SMD_$DEL_TRK_RECT

  - Every caller's rectangle is read once outside the tracking-rectangle
    lock, as smd_$add_trk_rects_internal does.
  - The cursor is redrawn at the display's own position after the lock.

  Status stored:
    status_$ok: each rectangle was found once
    smd_$bad_tracking_rect: the list did not shrink by exactly count
}

{ TODO(pascal) frame of SMD_$DEL_TRK_RECT (0x14 bytes) not accounted

  The image allocates 0x14 bytes: touch at -0x8..-0x1 and a pointer at
  -0x14 (stored and stepped: a compiler temporary for the second pointer
  to tracking_rects[j], the registers being taken).  Nothing addresses
  -0xC..-0x9.  The register-held old_count, i and j may account for it.
  dpc's `--dump-locals' gives 14 bytes, touch at -8, old_count at -10, i
  at -12 and j at -14, and no room for the temporary at -0x14 (the
  image's 0x14 has 4 bytes for its three words and the temporary below
  them, if the 4 bytes are any of them). }

procedure smd_$del_trk_rect(in rects: univ smd_track_rect_list_t;
                            in count: integer;
                            out status: status_$t);
var
  touch: smd_track_rect_t;
  old_count: integer;
  i: integer;
  j: integer;
begin
  status.all := status_$ok;

  { read each of the caller's rectangles, outside the lock }
  for i := 1 to count do
    touch := rects[i];

  ml_$exclusion_start(smd_$wired_data.trk_rect_mutex);
  old_count := tracking_rect_count;

  { remove every entry equal to each rectangle, the last entry moving
    into the hole }
  for i := 1 to count do begin
    j := 1;
    while j <= tracking_rect_count do
      if rects[i] = tracking_rects[j] then begin
        tracking_rects[j] :=
          tracking_rects[tracking_rect_count];
        tracking_rect_count := tracking_rect_count - 1;
      end
      else
        j := j + 1;
  end;

  { every rectangle must have been found once }
  if tracking_rect_count + count <> old_count then
    status.all := smd_$bad_tracking_rect;

  cursor_pending_flag := true;
  ml_$exclusion_stop(smd_$wired_data.trk_rect_mutex);

  { redraw the cursor at the display's own position }
  show_cursor(cursor_pos_sentinel, -1, true);
end;
