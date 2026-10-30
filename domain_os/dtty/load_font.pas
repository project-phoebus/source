{ dtty_$load_font - copy a font into the display's hidden memory.

  Image addresses:
    sau2  0x00E1D668  dtty_$load_font
    sau9  0x3C420044  dtty_$load_font

  - The display type is asked for and ignored (not with
    `smd_display_memory'); the result is always 0.

  Status stored:
    smd_$copy_font_to_md_hdm's status: always
}

function dtty_$load_font(var font_ptr: univ_ptr;
                         out status: status_$t): integer; internal;
begin
%if not smd_display_memory %then
  discard(dtty_$get_disp_type);
%endif
  discard(smd_$copy_font_to_md_hdm(font_ptr, status));
  dtty_$load_font := 0;
end;
