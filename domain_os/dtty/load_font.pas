{ dtty_$load_font - copy a font into the display's hidden memory.

  Image addresses:
    sau2  0x00E1D668  dtty_$load_font
    sau4  0x0F81E954  dtty_$load_font
    sau9  0x3C420044  dtty_$load_font

  - The display type is asked for and ignored (not with
    `smd_display_memory'); the result is always 0.
  - With `dtty_color_board' the color board gets its mode word back
    first when the display is the board's.

  Status stored:
    smd_$copy_font_to_md_hdm's status: always
}

function dtty_$load_font(var font_ptr: univ_ptr;
                         out status: status_$t): integer; internal;
%if dtty_color_board %then
var
  saved: dtty_color_mode_t;
%endif
begin
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
%if dtty_color_board %then
  dtty_$get_disp_type;
%elseif not smd_display_memory %then
  discard(dtty_$get_disp_type);
%endif
  discard(smd_$copy_font_to_md_hdm(font_ptr, status));
  dtty_$load_font := 0;
end;
