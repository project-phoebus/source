{ FILE_$LOCAL_LOCK_VERIFY - whether this node's lock table holds a lock
  that a lock record describes.

  Image addresses:
    sau2  0x00E6081C  FILE_$LOCAL_LOCK_VERIFY

  - Under the lock-table lock the object's hash chain is searched for an
    entry of the record's object and side whose mode is the record's
    (or, not pending, maps to it through the mode map).

  Status stored:
    status_$ok: a match, or remote negotiations are outstanding
    file_$object_not_locked_by_this_process: no match
}

procedure file_$local_lock_verify(in request: file_$lock_info_t;
                                  out status_ret: status_$t);
var
  hash: integer;
  i: integer;
begin
  hash := uid_$hash(request.file_uid, 251);
  status_ret.all := file_$object_not_locked_by_this_process;
  ml_$lock(ml_$file_lock_lock);

  i := file_$lot_hashtab[hash];
  if file_$lot_pending <> 0 then
    status_ret.all := status_$ok
  else
    while i > 0 do
      with file_$lock_entries[i] do begin
        if (uid = request.file_uid) and (state.side = request.side) then begin
          if state.mode = request.mode then begin
            status_ret.all := status_$ok;
            exit;
          end;
          if not state.pending then
            if request.mode = file_$lock_mode_map[state.mode] then begin
              status_ret.all := status_$ok;
              exit;
            end;
        end;
        i := next;
      end;

  ml_$unlock(ml_$file_lock_lock);
end;
