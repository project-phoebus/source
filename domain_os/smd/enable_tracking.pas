{ SMD_$ENABLE_TRACKING - turn locator tracking on.

  Image addresses:
    sau2  0x00E6E45C  SMD_$ENABLE_TRACKING
    sau5  0x00E708DE  SMD_$ENABLE_TRACKING
    sau9  0x3C474E62  SMD_$ENABLE_TRACKING

  - window_id is the cursor number to track with; param2 is not read.

  Status stored:
    status_$ok: always
}

procedure smd_$enable_tracking(in window_id: integer; in param2: integer32;
                               out status: status_$t);
begin
  tracking_enabled := true;
  tracking_cursor_num := window_id;
  status.all := status_$ok;
end;
