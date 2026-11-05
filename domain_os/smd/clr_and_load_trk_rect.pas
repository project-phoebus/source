{ SMD_$CLR_AND_LOAD_TRK_RECT - replace the tracking list.

  Image addresses:
    sau2  0x00E6E59C  SMD_$CLR_AND_LOAD_TRK_RECT
    sau4  0x0F878D32  SMD_$CLR_AND_LOAD_TRK_RECT
    sau5  0x00E70A1E  SMD_$CLR_AND_LOAD_TRK_RECT
    sau6  0x78077DA6  SMD_$CLR_AND_LOAD_TRK_RECT
    sau7  0x3C481884  SMD_$CLR_AND_LOAD_TRK_RECT
    sau9  0x3C474FA4  SMD_$CLR_AND_LOAD_TRK_RECT

  Status stored:
    status_$ok: the list holds the count rectangles
    smd_$trkng_list_full: more than 200 were given; the list is left as
      it was
}

procedure smd_$clr_and_load_trk_rect(in rects: univ smd_track_rect_list_t;
                                     in count: integer;
                                     out status: status_$t);
begin
  if smd_$add_trk_rects_internal(true, rects, count) then
    status.all := status_$ok
  else
    status.all := smd_$trkng_list_full;
end;
