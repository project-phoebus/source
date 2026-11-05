{ dtty_$load_font - copy a font into the display's hidden memory.

  Image addresses:
    sau2  0x00E1D668  dtty_$load_font
    sau4  0x0F81E954  dtty_$load_font
    sau6  0x7801F884  dtty_$load_font
    sau7  0x3C42192C  dtty_$load_font
    sau9  0x3C420044  dtty_$load_font

  - The display type is asked for and ignored (not with
    `smd_display_memory'); the result is always 0.
  - With `dtty_color_board' the color board gets its mode word back
    first when the display is the board's.
  - With `dtty_gpu' the graphics processor, when there is one
    (SMD_$GRAPHIC_DEVICE_ID 1 or 2), gets the font command first.

  Status stored:
    smd_$copy_font_to_md_hdm's status: always
}

function dtty_$load_font(var font_ptr: univ_ptr;
                         out status: status_$t): integer; internal;
%if dtty_gpu %then
var
  cmd: dtty_gpu_font_t;
  saved: dtty_color_mode_t;               { the SAU5's color board arm's }
%elseif dtty_color_board %then
var
  saved: dtty_color_mode_t;
%endif
begin
%if dtty_gpu %then
  if (smd_$graphic_device_id = smd_gdev_color2)
     or else (smd_$graphic_device_id = smd_gdev_color3) then begin
    cmd.op := dtty_gpu_op_font;
    cmd.count := 6;
    cmd.args[1] := 0;
    cmd.args[2] := 0;
    cmd.args[3] := 0;
    cmd.args[4] := 1024;
    cmd.args[5] := 1024;
    cmd.args[6] := 0;
    dtty_$gpu_command(addr(cmd), 8);
  end;
%endif
%if dtty_color_board %then
  { the color board's mode word sent back, low byte all ones, when the
    display is the color board's }
  if dtty_flag_04 then
    with color_sup do begin
      dtty_$get_disp_type;
      saved.all := mode;
      saved.low := true;
      data := 16#F803;
      while 15 in status do { empty };
      data := saved.all;
    end;
%endif
%if dtty_color_board or dtty_gpu %then
  dtty_$get_disp_type;
%elseif not smd_display_memory %then
  discard(dtty_$get_disp_type);
%endif
  discard(smd_$copy_font_to_md_hdm(font_ptr, status));
  dtty_$load_font := 0;
end;
