{ dir_$truncate_pages - invalidate a directory's pages past a new end.

  Image addresses:
    sau2  0x00E4E90A  dir_$truncate_pages

  - The split-in-progress flag is cleared; AST_$INVALIDATE's status is
    never looked at.

  Status stored:
    status_$ok: always
}

procedure dir_$truncate_pages(var handle: dir_$handle_t; page_count: pinteger;
                              out status_ret: status_$t);
  internal;
var
  local_uid: uid_$t;
  local_status: status_$t;
  remove: integer;
begin
  remove := handle.length div 1024 - page_count;

  local_uid := handle.uid;

  ast_$invalidate(local_uid, page_count, remove, true, local_status);

  handle.split_busy := false;

  status_ret.all := status_$ok;
end;
