{ dir_$alloc_overflow_page - put a long soft link's text on a page of
  its own (nested in dir_$add_entry).

  Image addresses:
    sau2  0x00E4E960  dir_$alloc_overflow_page (nested)

  - The page after the last one in use (none in use crashes the system)
    becomes add_entry's overflow_page, the directory grown to it if
    need be (AST_$TRUNCATE).
  - The text goes in from the page's second byte; a failed purify
    invalidates the page.
  - Nested in dir_$add_entry, whose frame it reaches.

  Status stored:
    status_$ok: the text's page was purified
    ast_$truncate's or ast_$purify's status: that step failed
}

  procedure dir_$alloc_overflow_page(out status_ret: status_$t);
  var
    uid_copy: uid_$t;
    page_list: integer32;
    inv_status: status_$t;
    trunc_result: boolean;
    page: dir_$root_page_ptr_t;
    text: dir_$text_ptr_t;
    i: integer;
  begin
    status_ret.all := status_$ok;

    overflow_page := handle.length div 1024 - 1;

    { the last page in use }
    repeat
      page := dir_$map_page(handle, overflow_page);
      if page^.word_00 <> 0 then
        exit;
      if overflow_page = 0 then
        crash_system(status_$naming_internal_error);
      overflow_page := overflow_page - 1;
    until false;

    overflow_page := overflow_page + 1;

    { grow the directory to cover the page }
    if (overflow_page + 1) * 1024 >= handle.length then begin
      ast_$truncate(handle.uid, (overflow_page + 2) * 1024, 0, trunc_result,
                    status_ret);
      if status_ret.all <> status_$ok then
        return;
      handle.length := (overflow_page + 2) * 1024;
    end;

    page := dir_$map_page(handle, overflow_page);
    page^.word_00 := 0;
    page^.hdr.flags.kind := 2;

    { the text from the page's second byte }
    text := dir_$text_ptr_t(integer32(page) + 1);
    for i := 1 to link_len do
      text^[i] := link_data[i];

    uid_copy := handle.uid;
    page_list := overflow_page;

    ast_$purify(handle.uid, 16#12, 0, page_list, 1, status_ret);

    if status_ret.all <> status_$ok then
      ast_$invalidate(uid_copy, overflow_page, 1, true, inv_status);
  end;
