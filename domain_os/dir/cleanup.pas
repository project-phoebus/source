{ DIR_$CLEANUP - release every directory handle the current process holds.

  Image addresses:
    sau2  0x00E53578  DIR_$CLEANUP

  - A handle in a split with a page still wired has that page copied
    back from the directory and unwired, and the pages validated.
  - A handle not in a split must have no page wired; inconsistencies
    crash the system.
  - The link buffer's mutex is released if this process owns it, and
    OLD_DIR cleans up.

  Status stored: none.
}

{ TODO(pascal) DIR_$CLEANUP's open frame bytes

  The SAU2 image's frame holds dir_uid, status, h and two element
  pointers of the compiler's (24 bytes), and 24 bytes no object
  explains, about one slot per register-held local if each keeps one:
  the same open point as the other DIR frames' TODOs
  (dir/README.md's list). }

procedure dir_$cleanup;
var
  dir_uid: uid_$t;
  status: status_$t;
  h: dir_$handle_ptr_t;
  slot: integer;
  page: integer;
  pg: dir_$root_page_ptr_t;
begin
  for slot := 0 to 31 do
    if (slot in dir_$handle_in_use) and then
       (dir_$handle_tab[slot].owner = proc1_$current) then begin
      h := addr(dir_$handle_tab[slot]);

      { a handle in a split }
      if h^.split_busy then begin
        if dir_$handle_tab[slot].max_slots <> 2 then begin
          page := dir_$handle_tab[slot].length div 1024 - 1;
          dir_uid := uid_$nil;

          { back to the wired buffer's page }
          repeat
            pg := dir_$map_page(h^, page);
            if dir_uid = uid_$nil then
              dir_uid := pg^.hdr.dir_uid;
            if ((pg^.hdr.flags.kind <> 0) and then
                (pg^.hdr.flags.kind <> 1)) or else
               (pg^.hdr.flags.format = 0) or else
               (dir_uid <> pg^.hdr.dir_uid) or else
               (page = pg^.hdr.page_no) then
              crash_system(status_$naming_internal_error);
            if pg^.hdr.page_no =
               dir_$page_hdr_ptr_t(dir_$handle_tab[slot].buf)^.page_no then
              exit;
            if page = 0 then
              crash_system(status_$naming_internal_error);
            page := page - 1;
          until false;

          { the page back over the buffer }
          dir_$root_page_ptr_t(dir_$handle_tab[slot].buf)^ := pg^;
          dir_$root_page_ptr_t(dir_$handle_tab[slot].buf)^.hdr.dir_uid.high
            := 0;
          dir_$root_page_ptr_t(dir_$handle_tab[slot].buf)^.hdr.flags.
            split_mark := false;
          dir_$release_wire(h^);
        end;

        dir_$validate_pages(h^, true, status);
      end

      { no split: nothing may be wired }
      else if dir_$handle_tab[slot].max_slots <> 2 then
        crash_system(status_$naming_internal_error);

      dir_$release_handle(h);
    end;

  if proc1_$current = dir_$link_buf_owner then begin
    dir_$link_buf_owner := 0;
    ml_$exclusion_stop(dir_$link_buf_mutex);
  end;

  dir_$old_cleanup;
end;
