{ dir_$next_page - the next leaf page of a directory's B-tree after a
  recorded path.

  Image addresses:
    sau2  0x00E4D7B0  dir_$next_page

  - From the leaf's parent upwards, the first level with an entry after
    the recorded one takes it, and the first children below it become
    the new path.
  - The page handed back is the new leaf's, 16#FFFF when there is none.

  Status stored: none.
}

{ TODO(pascal) 0x1C bytes of dir_$next_page's frame

  The SAU2 image's frame is 0x30 bytes; it addresses only the
  compiler's element pointer of the outer loop.  The reserved slot and
  one slot for each of the five register-held locals account for 0x10
  bytes (`dpc --dump-locals'), the pointer for 4 more.  What the
  remaining bytes held is not known; no stand-in is declared, as the
  routine's other locals' places are not known either. }

procedure dir_$next_page(var handle: dir_$handle_t; depth: integer;
                         in out path: univ dir_$path_t;
                         out page_ret: pinteger);
  internal;
var
  last: integer;
  i: integer;
  j: integer;
  base: integer;
  page: dir_$root_page_ptr_t;
begin
  page_ret := 16#FFFF;
  last := depth - 1;

  for i := last downto 1 do begin
    page := dir_$map_page(handle, path[i].page_no);
    if page^.hdr.page_no = 0 then
      base := 16#12 + page^.root_len
    else
      base := 16#12;

    if (page^.hdr.index_end - base) div 2 > path[i].entry_idx then begin
      path[i].entry_idx := path[i].entry_idx + 1;
      page_ret := dir_$entry_ptr_t(
                    dir_$index_ptr_t(base + integer32(page))^
                      [path[i].entry_idx] + integer32(page))^.child;

      { down to the leaf, first entries }
      for j := i + 1 to last do begin
        path[j].page_no := page_ret;
        path[j].entry_idx := 1;
        page := dir_$map_page(handle, page_ret);
        page_ret := dir_$entry_ptr_t(
                      dir_$index_ptr_t(16#12 + integer32(page))^[1] +
                      integer32(page))^.child;
      end;
      return;
    end;
  end;
end;
