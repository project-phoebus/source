{ smd_$add_trk_rects_internal - add rectangles to the tracking list.

  Image addresses:
    sau2  0x00E6E4D4  smd_$add_trk_rects_internal (module-local)
    sau5  0x00E70956  smd_$add_trk_rects_internal (module-local)
    sau9  0x3C474EDC  smd_$add_trk_rects_internal (module-local)

  - clear empties the list first (SMD_$CLR_AND_LOAD_TRK_RECT's); the
    result is whether there was room for the rectangles (200 at most).
  - The caller's first and last rectangle are read before the
    tracking-rectangle lock is taken, touching the array outside it.
  - The cursor is redrawn at the display's own position after the lock.

  Status stored: none.
}

{ TODO(pascal) frame of smd_$add_trk_rects_internal (0x18 bytes) not accounted

  The image allocates 0x18 bytes.  The addressed objects are the
  module-local's 4-byte slot at -4 and touch's 8 bytes at -0x10..-0x9;
  nothing addresses -0x8..-0x5 or -0x18..-0x11.  The result variable
  (boolean) and the register-held locals ok and i may account for some
  of it.  dpc's `--dump-locals' gives 18 bytes, ok at -14 and i at -16,
  and touch above them at -12 (4 bytes higher than the image's -0x10):
  the image has 4 more bytes between the slot and touch, and 6 more
  below. }

function smd_$add_trk_rects_internal(clear: boolean;
                                     in rects: smd_track_rect_list_t;
                                     count: pinteger): boolean; internal;
var
  touch: smd_track_rect_t;
  ok: boolean;
  i: pinteger;
begin
  { read the caller's first and last rectangle, outside the lock }
  if count <> 0 then begin
    touch := rects[1];
    touch := rects[count];
  end;

  ml_$exclusion_start(smd_$wired_data.trk_rect_mutex);

  { room for the new rectangles }
  if clear then
    ok := count <= 200
  else
    ok := tracking_rect_count + count <= 200;

  { empty the list when clearing, then append }
  if ok then begin
    if clear then
      tracking_rect_count := 0;
    for i := 1 to count do
      tracking_rects[i + tracking_rect_count] := rects[i];
    tracking_rect_count := tracking_rect_count + count;
  end;

  ml_$exclusion_stop(smd_$wired_data.trk_rect_mutex);

  { redraw the cursor at the display's own position }
  show_cursor(cursor_pos_sentinel, -1, true);
  smd_$add_trk_rects_internal := ok;
end;
