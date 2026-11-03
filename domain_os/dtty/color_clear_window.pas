{ dtty_$color_clear_window - clear a window of the color board's display.

  Image addresses:
    sau4  0x0F81E826  dtty_$color_clear_window (module-local)

  - The board's clear command, 16#F100, with the window's left and
    bottom limits and then its right and top limits as one longword,
    five words in all.
  - With `dtty_color_board' only.

  Status stored:
    status_$ok: always
}

procedure dtty_$color_clear_window(in window: univ dtty_color_window_view_t;
                                   out status: status_$t); internal;
var
  cmd: dtty_color_clear_t;
begin
  status.all := status_$ok;
  cmd.op := dtty_color_op_clear;
  cmd.xs := window.xs;
  cmd.ye := window.ye;
  cmd.xe_ys := window.xe_ys;
  dtty_$color_command(cmd, 5);
end;
