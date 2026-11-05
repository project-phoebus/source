{ SMD_$DISABLE_TRACKING - turn locator tracking off.

  Image addresses:
    sau2  0x00E6E482  SMD_$DISABLE_TRACKING
    sau4  0x0F878C18  SMD_$DISABLE_TRACKING
    sau5  0x00E70904  SMD_$DISABLE_TRACKING
    sau6  0x78077C8E  SMD_$DISABLE_TRACKING
    sau7  0x3C481768  SMD_$DISABLE_TRACKING
    sau9  0x3C474E88  SMD_$DISABLE_TRACKING

  - Cursor 0 is redrawn at the display's own position, waiting for the
    display; param1 is not read.

  Status stored:
    status_$ok: always
}

procedure smd_$disable_tracking(in param1: integer32;
                                out status: status_$t);
begin
  tracking_enabled := false;
  show_cursor(cursor_pos_sentinel, 0, true);
  status.all := status_$ok;
end;
