{ SMD_$ADD_TRK_RECT - add rectangles to the tracking list.

  Image addresses:
    sau2  0x00E6E5D8  SMD_$ADD_TRK_RECT
    sau4  0x0F878D6E  SMD_$ADD_TRK_RECT
    sau5  0x00E70A5A  SMD_$ADD_TRK_RECT
    sau9  0x3C474FE0  SMD_$ADD_TRK_RECT

  Status stored:
    status_$ok: the rectangles were added
    smd_$trkng_list_full: the list would hold more than 200; it is left
      as it was
}

procedure smd_$add_trk_rect(in rects: univ smd_track_rect_list_t;
                            in count: integer;
                            out status: status_$t);
begin
  if smd_$add_trk_rects_internal(false, rects, count) then
    status.all := status_$ok
  else
    status.all := smd_$trkng_list_full;
end;
