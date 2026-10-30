{ COLOR_$UNMAP - unload and unwire the last pages COLOR_$MAP loaded.

  Image addresses:
    sau5  0x00E72F3A  COLOR_$UNMAP

  - The emptied entries get 16#AAAA twice.

  Status stored:
    status_$ok: the pages were unloaded
    status_$color_illegal_caller: the caller does not own the board
    status_$color_pages_unmapped_out_of_order: the entries from offset
      (512 an entry) are not the last ones loaded, or npages is negative
}

procedure color_$unmap(in offset: integer32; in npages: integer;
                       out status: status_$t);
var
  first: integer;
  k: integer;
  page: linteger;
begin
  if color_owner <> proc1_$current then begin
    status.all := status_$color_illegal_caller;
    return;
  end;
  first := linteger(offset) div 512;
  if (first + npages <> color_page_count) or else (npages < 0) then begin
    status.all := status_$color_pages_unmapped_out_of_order;
    return;
  end;
  status.all := status_$ok;
  color_page_count := color_page_count - npages;
  for k := first to first + npages - 1 do begin
    page := color_pages[k];
    wp_$unwire(page);
    color_$load_map(addr(color_sup.map[k]), -16#5556, -16#5556);
  end;
end;
