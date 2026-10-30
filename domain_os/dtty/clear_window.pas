{ dtty_$clear_window - clear a window of the display.

  Image addresses:
    sau2  0x00E1D592  dtty_$clear_window
    sau9  0x3C41FF7A  dtty_$clear_window

  - With `smd_display_memory' the whole screen is cleared
    (SMD_$CLEAR_SCREEN), whatever the window.

  Status stored:
    smd_$clear_window's status: always
    status_$ok: with `smd_display_memory'
}

procedure dtty_$clear_window(in window: smd_$window_limits_t;
                             out status: status_$t); internal;
begin
  status.all := status_$ok;
%if smd_display_memory %then
  smd_$clear_screen;
%else
  smd_$clear_window(window, status);
%endif
end;
