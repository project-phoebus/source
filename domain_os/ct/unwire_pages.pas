{ ct_unwire_pages - unwire the pages of a list and empty it.

  Image addresses:
    sau5  0x00E76F10  ct_unwire_pages (module-local)
    sau9  0x3C477BDE  ct_unwire_pages (module-local)
    sau8  0x03C7A0CC  ct_unwire_pages (module-local)

  - Each entry's page is unwired (WP_$UNWIRE), but a flagged entry's
    (one that may repeat the page before it) only when it is not the
    page last unwired; then the count is set to 0.

  Status stored: none.
}

procedure ct_unwire_pages(in pages: univ ct_$page_list_t;
                          in flags: univ ct_$page_flags_t;
                          in out count: integer); internal;
var
  last: integer32;
  page: integer32;
  i: integer;
begin
  last := 0;
  for i := 1 to count do begin
    page := pages[i];
    if not flags[i] then begin
      wp_$unwire(page);
      last := page;
    end
    else if page <> last then
      wp_$unwire(page);
  end;
  count := 0;
end;
