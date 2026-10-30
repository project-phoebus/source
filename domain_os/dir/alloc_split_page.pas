{ dir_$alloc_split_page - choose the pages a split will use and copy the
  path's pages to them (nested in dir_$insert_entry).

  Image addresses:
    sau2  0x00E4EB40  dir_$alloc_split_page (nested)

  - The new pages come from the gap after the last page in use, free
    pages below it (AST_$GET_SEG_MAP), then past the gap.
  - The path's pages are copied to them under a new directory UID.
  - Nested in dir_$insert_entry (itself nested in dir_$add_entry).

  Status stored:
    dir_$purify_split_pages' status: the pages were copied
    ast_$get_seg_map's status: the segment map could not be read
}

{ TODO(pascal) the AST_$GET_SEG_MAP location argument never assigned

  The third argument of AST_$GET_SEG_MAP is the local location, which
  this routine never writes: whatever the frame held.  AST_$GET_SEG_MAP
  clears that by-value slot before it reads it (ast/ast.ins.pas), so the
  value does not matter; dir_$open_dir assigns its own location 0 first,
  FILE_$GET_SEG_MAP passes a local too.  The Pascal keeps the unassigned
  local; whether the source assigned it somewhere the compiler dropped,
  or never, is not known. }

    procedure dir_$alloc_split_page(flag: boolean; out status_ret: status_$t);
    label
      10;
    var
      local_uid: uid_$t;
      seg_map: ast_$seg_map_t;
      seg_status: status_$t;
      location: integer32;
      max_seg: pinteger;
      seg_idx: pinteger;
      next_page: integer;
      first_free: pinteger;
      base_count: integer;
      pages_needed: integer;
      gap: integer;
      split_idx: integer;
      page_base: integer;
      dest_page: integer;
      page_no: pinteger;
      root: dir_$root_page_ptr_t;
      dest: dir_$root_page_ptr_t;
      page: dir_$root_page_ptr_t;
      i: integer;
      w: integer;
      bit: integer;
      level: integer;
    begin
      with handle do begin
        current_slot := slot_idx;

        if flag then
          pages_needed := max_depth - slot_idx + 2
        else
          pages_needed := max_depth - slot_idx;

        base_count := max_depth - slot_idx + 1;

        first_free := length div 1024 - 1;

        { the last page in use }
        repeat
          page := dir_$map_page(handle, first_free);
          if page^.word_00 <> 0 then
            exit;
          if first_free = 0 then
            crash_system(status_$naming_internal_error);
          first_free := first_free - 1;
        until false;

        first_free := first_free + 1;

        { the free pages at the end }
        gap := length div 1024 - first_free;
        if gap < base_count then begin
          next_page := length div 1024 - gap;
          gap := 0;
        end
        else begin
          next_page := length div 1024 - base_count;
          gap := gap - base_count;
        end;

        if pages_needed > gap then begin
          { the gap's pages first }
          split_idx := base_count;
          for i := 1 to gap do begin
            split_idx := split_idx + 1;
            split_pages[split_idx] := first_free + i - 1;
          end;

          pages_needed := pages_needed - gap;
          root := dir_$map_page(handle, 0);
          if root^.hdr.flags.seg_map_valid then begin
            seg_idx := 0;
            max_seg := (first_free - 1) div 32;
            page_base := 0;

            { free pages below the gap }
            repeat
              local_uid := uid;
              ast_$get_seg_map(local_uid, seg_idx * 32768, location, 1,
                               16#20, [1], seg_map, seg_status);
              if seg_status.all <> status_$ok then begin
                status_ret := seg_status;
                return;
              end;
              for w := 0 to 0 do
                for bit := 0 to 31 do
                  if not (bit in seg_map[w]) then begin
                    page_no := bit + page_base + 32 * w;
                    if (page_no >= first_free) or else
                       (page_no = 0) then begin
                      root^.hdr.flags.seg_map_valid := false;
                      goto 10;
                    end;
                    split_idx := split_idx + 1;
                    split_pages[split_idx] := page_no;
                    pages_needed := pages_needed - 1;
                    if pages_needed = 0 then
                      goto 10;
                  end;
            10:
              seg_idx := seg_idx + 1;
              page_base := page_base + 32;
            until (seg_idx > max_seg) or else (pages_needed = 0);
          end;

          { the rest past next_page }
          if pages_needed <> 0 then begin
            for i := 1 to pages_needed do
              split_pages[split_idx + i] := next_page + i - 1;
            next_page := next_page + pages_needed;
          end;
        end
        else
          { all from the gap }
          for i := 1 to pages_needed do
            split_pages[base_count + i] := first_free + i - 1;

        { the path's new places }
        for i := 1 to base_count do
          split_pages[i] := next_page + i - 1;

        if (base_count + next_page) * 1024 > length then
          length := (base_count + next_page) * 1024;

        uid_$gen(dir_uid);

        { copy the path's pages }
        dest_page := next_page;
        for level := max_depth downto slot_idx do begin
          dest := dir_$map_page(handle, dest_page);
          page_data := dir_$map_page(handle, path[level].page_no);
          dest^ := page_data^;
          dest^.hdr.dir_uid := dir_uid;
          dest^.hdr.flags.split_mark := (level = 1) and flag;
          dest_page := dest_page + 1;
        end;

        page_count := base_count;

        dir_$purify_split_pages(status_ret);

        if status_ret.all = status_$ok then begin
          split_busy := true;
          idx_base := dir_$index_ptr_t(base_offset + integer32(page_data));
        end;
      end;
    end;
