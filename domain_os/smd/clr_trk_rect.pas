{ SMD_$CLR_TRK_RECT - empty the tracking list.

  Image addresses:
    sau2  0x00E6E718  SMD_$CLR_TRK_RECT
    sau5  0x00E70B96  SMD_$CLR_TRK_RECT
    sau9  0x3C47510C  SMD_$CLR_TRK_RECT

  - The cursor is redrawn at the display's own position after the
    tracking-rectangle lock is released.

  Status stored:
    status_$ok: always
}

procedure smd_$clr_trk_rect(out status: status_$t);
begin
  ml_$exclusion_start(smd_$wired_data.trk_rect_mutex);
  tracking_rect_count := 0;
  ml_$exclusion_stop(smd_$wired_data.trk_rect_mutex);
  cursor_pending_flag := true;
  show_cursor(cursor_pos_sentinel, -1, true);
  status.all := status_$ok;
end;
