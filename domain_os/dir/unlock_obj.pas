{ dir_$unlock_obj - release a handle's lock on its directory object.

  Image addresses:
    sau2  0x00E4B234  dir_$unlock_obj

  - A write lock on a mapped directory is purified first (a failure
    crashes the system).
  - Under DIR_$MUTEX the count is released (one that does not fit the
    mode crashes the system); the first waiter is woken at 0, else a
    record nobody holds goes back on the free list.

  Status stored: none.
}

procedure dir_$unlock_obj(var handle: dir_$handle_t);
  internal;
var
  local_status: status_$t;
  lock: dir_$lock_entry_ptr_t;
  first: dir_$handle_ptr_t;
begin
  if handle.lock_mode = 0 then
    return;

  { a written, mapped directory is purified }
  if (handle.lock_mode = 2) and then handle.map.info.active then begin
    ast_$purify(handle.uid, 0, 0, 0, 0, local_status);
    if local_status.all <> status_$ok then
      crash_system(local_status);
  end;

  ml_$exclusion_start(dir_$mutex);
  lock := handle.lock_entry;
  if handle.lock_mode = 1 then begin
    if lock^.lock_count <= 0 then
      crash_system(status_$naming_internal_error);
    lock^.lock_count := lock^.lock_count - 1;
  end
  else if handle.lock_mode = 2 then begin
    if lock^.lock_count <> -1 then
      crash_system(status_$naming_internal_error);
    lock^.lock_count := 0;
  end;

  first := lock^.waiters;
  if first <> nil then begin
    if lock^.lock_count = 0 then
      ec_$advance(dir_$wait_ecs[first^.slot_index]);
  end
  else if lock^.lock_count = 0 then begin
    lock^.next := dir_$lock_free;
    dir_$lock_free := handle.lock_entry;
    dir_$lock_in_use := dir_$lock_in_use - [lock^.index];
  end;

  handle.lock_entry := nil;
  ml_$exclusion_stop(dir_$mutex);
end;
