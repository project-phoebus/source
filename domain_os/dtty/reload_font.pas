{ DTTY_$RELOAD_FONT - copy the standard font into the display's hidden
  memory again.

  Image addresses:
    sau2  0x00E1D73A  DTTY_$RELOAD_FONT
    sau4  0x0F81EA5A  DTTY_$RELOAD_FONT
    sau6  0x7801F9AA  DTTY_$RELOAD_FONT
    sau7  0x3C4219EA  DTTY_$RELOAD_FONT

  - The status and the result are ignored.

  Status stored: none.
}

procedure dtty_$reload_font;
var
  status: status_$t;
begin
  discard(dtty_$load_font(dtty_$std_font_p, status));
end;
