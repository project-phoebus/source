{ dtty_$color_clear_window - clear a window of the color board's display.

  Image addresses:
    sau4  0x0F81E826  dtty_$color_clear_window (module-local)
    sau6  0x7801F72E  dtty_$color_clear_window (module-local)

  - The board's clear command, 16#F100, with the window's left and
    bottom limits and then its right and top limits as one longword,
    five words in all.
  - With `dtty_gpu' the graphics processor's clear command, 16#E000,
    with the window's left, bottom, right and top limits, when there is
    a processor (SMD_$GRAPHIC_DEVICE_ID 1 or 2).
  - With `dtty_color_board' or `dtty_gpu' only.

  Status stored:
    status_$ok: always
}

%if dtty_gpu %then
procedure dtty_$color_clear_window(in window: smd_$window_limits_t;
                                   out status: status_$t); internal;
var
  gpu_cmd: dtty_gpu_clear_t;
  cmd: dtty_color_clear_t;                { the SAU5's color board arm's }
begin
  status.all := status_$ok;
  if (smd_$graphic_device_id = smd_gdev_color2)
     or else (smd_$graphic_device_id = smd_gdev_color3) then begin
    gpu_cmd.op := dtty_gpu_op_clear;
    gpu_cmd.count := 4;
    gpu_cmd.xs := window.xs;
    gpu_cmd.ys := window.ys;
    gpu_cmd.xe := window.xe;
    gpu_cmd.ye := window.ye;
    dtty_$gpu_command(addr(gpu_cmd), 6);
  end;
end;
%else
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
%endif
