{ dir_$lock_obj - lock a directory object for a handle.

  Image addresses:
    sau2  0x00E4AFA8  dir_$lock_obj

  - Under DIR_$MUTEX, the UID's lock record is found or taken off the
    free list (an empty list crashes the system).
  - Up to three attempts: a writer (mode 2) needs no holder, a reader
    (mode 1) no writer.  Otherwise it queues and waits, the mutex
    released, 8 ticks for a server helper with its short-wait flag,
    else 480.

  Status stored:
    status_$ok: the lock was granted
    status_$naming_directory_locked: the attempts ran out, or a wait
      timed out
}

procedure dir_$lock_obj(var handle: dir_$handle_t; mode: integer;
                        out status_ret: status_$t);
  internal;
var
  wait_val: integer32;
  is_server: boolean;
  i: integer;
  lock: dir_$lock_entry_ptr_t;
  attempt: integer;
  q: dir_$handle_ptr_t;
  timeout: integer32;
  wake: integer;
begin
  is_server := proc1_$type[proc1_$current] = 9;
  handle.lock_entry := nil;
  handle.lock_mode := mode;
  ml_$exclusion_start(dir_$mutex);

  { the record already in use for the UID }
  for i := 0 to 31 do
    if (i in dir_$lock_in_use) and then
       (dir_$lock_tab[i].uid = handle.uid) then begin
      handle.lock_entry := addr(dir_$lock_tab[i]);
      exit;
    end;

  { else a free one }
  if handle.lock_entry = nil then begin
    handle.lock_entry := dir_$lock_free;
    if handle.lock_entry = nil then
      crash_system(status_$naming_internal_error);
    with handle.lock_entry^ do begin
      dir_$lock_in_use := dir_$lock_in_use + [index];
      dir_$lock_free := next;
      uid := handle.uid;
      waiters := nil;
      lock_count := 0;
    end;
  end;

  status_ret.all := status_$naming_directory_locked;
  lock := handle.lock_entry;

  for attempt := 1 to 3 do begin
    { granted }
    if ((lock^.waiters = nil) or (attempt > 1)) and then
       (((mode = 2) and (lock^.lock_count = 0)) or else
        ((mode = 1) and then (lock^.lock_count >= 0))) then begin
      if mode = 1 then begin
        lock^.lock_count := lock^.lock_count + 1;
        if lock^.waiters <> nil then
          if lock^.waiters^.lock_mode = 1 then
            ec_$advance(dir_$wait_ecs[lock^.waiters^.slot_index]);
      end
      else
        lock^.lock_count := -1;
      status_ret.all := status_$ok;
      exit;
    end;

    { join the queue }
    q := lock^.waiters;
    if q = nil then
      lock^.waiters := addr(handle)
    else begin
      while q^.next <> nil do
        q := q^.next;
      q^.next := addr(handle);
    end;
    handle.next := nil;

    if attempt > 2 then
      dir_$lk_wait_2 := dir_$lk_wait_2 + 1;
    dir_$lk_waits := dir_$lk_waits + 1;

    if is_server and then (1 in dir_$proc_flags[proc1_$current]) then
      timeout := 8
    else
      timeout := 16#1E0;

    { wait, the mutex released }
    wait_val := dir_$wait_ecs[handle.slot_index].value + 1;
    ml_$exclusion_stop(dir_$mutex);
    wake := ec_$wait(addr(time_$clockh_ec),
                     addr(dir_$wait_ecs[handle.slot_index]),
                     addr(ec_$nil_ec), timeout + time_$clockh, wait_val, 0);
    ml_$exclusion_start(dir_$mutex);

    { leave the queue }
    if lock^.waiters = addr(handle) then
      lock^.waiters := handle.next
    else begin
      q := lock^.waiters;
      while q^.next <> addr(handle) do
        q := q^.next;
      q^.next := handle.next;
    end;

    { timed out }
    if wake = 0 then begin
      dir_$lk_timeouts := dir_$lk_timeouts + 1;
      exit;
    end;
  end;

  { failed }
  if status_ret.all <> status_$ok then begin
    handle.lock_mode := 0;
    if (lock^.lock_count = 0) and then (lock^.waiters = nil) then begin
      lock^.next := dir_$lock_free;
      dir_$lock_free := handle.lock_entry;
      dir_$lock_in_use := dir_$lock_in_use - [lock^.index];
      handle.lock_entry := nil;
    end;
  end;

  ml_$exclusion_stop(dir_$mutex);
end;
