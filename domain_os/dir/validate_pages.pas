{ dir_$validate_pages - check a directory's pages after an interrupted
  split and repair or truncate them.

  Image addresses:
    sau2  0x00E53728  dir_$validate_pages

  - From the last page down, while the pages are well formed and not at
    their own index; stopping on the last page, trailing format-0 pages
    are truncated.
  - Otherwise the pages above the stopping point are checked against
    their home pages; an inconsistency copies them back over their homes
    before the purify and the truncation.
  - An internal error crashes the system when crash_flag is set.

  Status stored:
    status_$ok: the pages were consistent
    dir_$truncate_pages' status: the pages were truncated
    ast_$purify's status: the purify failed
    status_$naming_internal_error: an internal error, crash_flag clear
}

{ TODO(pascal) dir_$validate_pages' open frame bytes

  The SAU2 frame holds dir_uid, next_data and the three flags (15 bytes)
  beside the reserved slot; 45 bytes no object explains, about one slot
  per register-held local if each keeps one: the same open point as the
  other DIR frames' TODOs (dir/README.md's list). }

procedure dir_$validate_pages(var handle: dir_$handle_t; crash_flag: boolean;
                              out status_ret: status_$t);
label
  20, 30;
var
  dir_uid: uid_$t;
  next_data: dir_$root_page_ptr_t;
  seen_forward: boolean;
  seen_backward: boolean;
  mismatch: boolean;
  page_limit: pinteger;
  cur: pinteger;
  start: pinteger;
  j: pinteger;
  left: pinteger;
  right: pinteger;
  next: pinteger;
  pg: dir_$root_page_ptr_t;
  fwd_data: dir_$root_page_ptr_t;
  ref_data: dir_$root_page_ptr_t;
  src_data: dir_$root_page_ptr_t;
  dst_data: dir_$root_page_ptr_t;
  idx: dir_$index_ptr_t;
begin
  status_ret.all := status_$ok;
  page_limit := handle.length div 1024 - 1;
  cur := page_limit;
  dir_uid := uid_$nil;

  { down from the last page }
  repeat
    pg := dir_$map_page(handle, cur);
    if dir_uid = uid_$nil then
      dir_uid := pg^.hdr.dir_uid;
    if ((pg^.hdr.flags.kind <> 0) and then
        (pg^.hdr.flags.kind <> 1)) or else
       (pg^.hdr.flags.format = 0) or else
       (dir_uid <> pg^.hdr.dir_uid) or else
       (cur = pg^.hdr.page_no) then
      exit;
    if cur = 0 then begin
      { the error block, as below }
      if crash_flag then
        crash_system(status_$naming_internal_error);
      status_ret.all := status_$naming_internal_error;
      return;
    end;
    cur := cur - 1;
  until false;

  if page_limit - cur = 0 then begin
    { past the empty trailing pages }
    repeat
      pg := dir_$map_page(handle, cur);
      if pg^.hdr.flags.format <> 0 then
        exit;
      cur := cur - 1;
    until false;

    if cur + 1 > page_limit then
      return;
    dir_$truncate_pages(handle, cur + 1, status_ret);
  end
  else begin
    mismatch := false;
    seen_forward := true;
    seen_backward := true;
    start := cur;

    { up from the stopping point }
    while cur < page_limit do begin
      cur := cur + 1;
      fwd_data := dir_$map_page(handle, cur);
      if start < fwd_data^.hdr.page_no then begin
        { the error block, as below }
        if crash_flag then
          crash_system(status_$naming_internal_error);
        status_ret.all := status_$naming_internal_error;
        return;
      end;
      ref_data := dir_$map_page(handle, fwd_data^.hdr.page_no);

      if dir_uid = ref_data^.hdr.dir_uid then begin
        if not seen_forward then
          goto 20;
        seen_backward := false;
        if fwd_data^.hdr.flags.split_mark then begin
          { a split interior page's two children }
          if ref_data^.hdr.flags.kind <> 1 then begin
            { the error block's one copy in the image }
            if crash_flag then
              crash_system(status_$naming_internal_error);
            status_ret.all := status_$naming_internal_error;
            return;
          end;
          idx := dir_$index_ptr_t(ref_data^.root_len +
                                  integer32(ref_data) + 16#12);
          left := dir_$entry_ptr_t(idx^[1] + integer32(ref_data))^.child;
          right := dir_$entry_ptr_t(idx^[2] + integer32(ref_data))^.child;
          if left > start then
            goto 20;
          if right > start then
            goto 20;
          pg := dir_$map_page(handle, left);
          if dir_uid <> pg^.hdr.dir_uid then
            goto 20;
          pg := dir_$map_page(handle, right);
          if dir_uid <> pg^.hdr.dir_uid then
            goto 20;
        end
        else if cur < page_limit then begin
          { a flat page's next page }
          next := ref_data^.hdr.next_page;
          if next > start then
            goto 20;
          next_data := dir_$map_page(handle, next);
          if dir_uid <> next_data^.hdr.dir_uid then
            goto 20;
        end;
      end
      else if not seen_backward then begin
      20:
        mismatch := true;
        goto 30;
      end
      else
        seen_forward := false;
    end;

    { the pages back over their home pages }
    if mismatch then begin
    30:
      j := start;
      while j < page_limit do begin
        j := j + 1;
        src_data := dir_$map_page(handle, j);
        dst_data := dir_$map_page(handle, src_data^.hdr.page_no);
        if dst_data^.hdr.dir_uid = dir_uid then begin
          dir_$wire_page(handle, dst_data);
          dst_data^ := src_data^;
          dst_data^.hdr.dir_uid.high := 0;
          dst_data^.hdr.flags.split_mark := false;
          dir_$release_wire(handle);
        end;
      end;
    end;

    ast_$purify(handle.uid, 2, 0, 0, 0, status_ret);
    if status_ret.all <> status_$ok then
      return;
    dir_$truncate_pages(handle, start + 1, status_ret);
  end;
end;
