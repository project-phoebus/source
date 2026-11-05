{ COLOR7_$COPY_FONT_MD_HDM - copy the font into the hidden display
  memory.

  Image addresses:
    sau7  0x3C48CEA4  COLOR7_$COPY_FONT_MD_HDM

  - The PROM's font is reloaded into the display (RELOAD_FONT); the
    descriptor and font_ptr are not read, and the result is 0.

  Status stored:
    status_$ok: always
}

[section(color7_wired_proc, wired_data)]
function color7_$copy_font_md_hdm(dcte: color7_$dcte_ptr_t;
                                  var font_ptr: univ_ptr;
                                  out status: status_$t): integer;
  options(val_param);
begin
  status.all := status_$ok;
  reload_font;
  color7_$copy_font_md_hdm := 0;
end;
