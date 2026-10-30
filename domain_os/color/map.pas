{ COLOR_$MAP - wire a buffer's pages and load them into the color map.

  Image addresses:
    sau5  0x00E72DFC  COLOR_$MAP

  - Each page is wired, touched and loaded into the next color map
    entry; offset is the first entry's number times 512.
  - A wiring failure unwires the pages this call wired.

  Status stored:
    mst_$wire's status: the pages were wired (not written when npages is
      0); a failure with its fail bit set
    status_$color_illegal_caller: the caller does not own the board
    status_$color_too_many_wired_pages: more than 33 pages in all
    status_$color_va_not_page_aligned: the buffer is not page aligned
}

procedure color_$map(in buffer: univ char; in npages: integer;
                     out offset: integer32; out status: status_$t);
type
  word_ptr_t = ^integer;
var
  va: linteger;
  first: integer;
  slot: integer;
  k: integer;
  page: linteger;
  touch: integer;
begin
  if color_owner <> proc1_$current then begin
    status.all := status_$color_illegal_caller;
    return;
  end;
  if color_page_count + npages > color_max_pages then begin
    status.all := status_$color_too_many_wired_pages;
    return;
  end;
  va := linteger(addr(buffer));
  if (va & 16#3FF) <> 0 then begin
    status.all := status_$color_va_not_page_aligned;
    return;
  end;
  first := color_page_count;
  for slot := first to first + npages - 1 do begin
    color_pages[slot] := mst_$wire(va, status);
    if status.code <> 0 then begin
      for k := first to slot - 1 do begin
        page := color_pages[k];
        wp_$unwire(page);
        color_page_count := color_page_count - 1;
      end;
      status.fail := true;
      return;
    end;
    color_page_count := color_page_count + 1;
    touch := word_ptr_t(va)^;
    word_ptr_t(va)^ := touch;
    color_$load_map(addr(color_sup.map[slot]),
                    ((color_pages[slot] div 128) & 16#7F) ! 16#1E80,
                    (color_pages[slot] * 512) & 16#FE00);
    va := va + 1024;
  end;
  offset := first * 512;
end;
