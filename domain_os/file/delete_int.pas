{ file_$delete_int - delete an object unless it is locked, or mark it
  for deletion when it is unlocked; answer whether it is locked.

  Image addresses:
    sau2  0x00E5E8E0  file_$delete_int

  - Under the lock-table lock the object's lock entry is looked up; the
    result is whether it was found locked.  Without flags bit 0 the
    routine only answers.
  - With bit 0 a locked object is refused, or with bits 1 and 2 gets its
    delete-when-unlocked attribute; an unlocked one is truncated to
    nothing (AST_$TRUNCATE) under its UID's bucket lock.

  Status stored:
    status_$ok: the object was deleted or marked, or only looked up
    file_$object_in_use: locked, and flags bit 1 clear
    file_$set_attribute's status: the attribute failed (but "object is
      remote" and "reference count says unused")
    ast_$truncate's status: the truncation
}

function file_$delete_int(in file_uid: uid_$t; flags: integer;
                          out result: boolean;
                          out status_ret: status_$t): boolean;
var
  value: file_$attr_value_t;
  trunc_flags: integer;
  found: boolean;
  hash: integer;
  i: integer;
begin
  result := false;
  found := false;
  hash := uid_$hash(file_uid, 251);

  { the bucket's chain }
  ml_$lock(ml_$file_lock_lock);
  i := file_$lot_hashtab[hash];
  while i > 0 do begin
    if file_uid = file_$lock_entries[i].uid then begin
      found := true;
      exit;
    end;
    i := file_$lock_entries[i].next;
  end;

  status_ret.all := status_$ok;

  if (flags & 1) <> 0 then
    if found then begin
      if (flags & 2) <> 0 then begin
        if (flags & 4) <> 0 then begin
          value.word_val := 1;
          file_$set_attribute(file_uid, 7, value, 0, -1, status_ret);
          if (status_ret.all = file_$object_is_remote) or else
             (status_ret.all = status_$ast_refcount_says_unused) then
            status_ret.all := status_$ok;
        end;
      end
      else
        status_ret.all := file_$object_in_use;
    end
    else begin
      file_$uid_lock_acquire(file_uid);
      ml_$unlock(ml_$file_lock_lock);
      trunc_flags := 1;
      if (flags & 4) <> 0 then
        trunc_flags := 3;
      ast_$truncate(file_uid, 0, trunc_flags, result, status_ret);
      ml_$lock(ml_$file_lock_lock);
      file_$uid_lock_release(file_uid);
    end;

  ml_$unlock(ml_$file_lock_lock);
  file_$delete_int := found;
end;
