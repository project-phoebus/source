{ MONO9_$COPY_FONT_MD_HDM - copy a font to hidden display memory: this
  display has none.

  Image addresses:
    sau9  0x3C476DF0  MONO9_$COPY_FONT_MD_HDM

  - Nothing is copied; the result is 1 and the font is not read.

  Status stored:
    status_$ok: always
}

function mono9_$copy_font_md_hdm(dcte: mono9_$dcte_ptr_t;
                                 var font: integer32;
                                 out status: status_$t): integer32;
  options(val_param);
begin
  status.all := status_$ok;
  mono9_$copy_font_md_hdm := 1;
end;
