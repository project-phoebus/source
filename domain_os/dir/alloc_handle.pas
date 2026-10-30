{ dir_$alloc_handle - take a directory handle off the free list.

  Image addresses:
    sau2  0x00E4B86E  dir_$alloc_handle (module-local)

  - Under DIR_$MUTEX.  With the list empty, a server helper (type 9)
    gets nil, a process holding a handle already the reserve, entry 0,
    if free; anyone else waits on DIR_$WT_FOR_HDNL_EC and tries again.
  - The handle is stamped with the process and reset (no wired page,
    max_slots 2).

  Status stored: none.
}

function dir_$alloc_handle: dir_$handle_ptr_t;
  internal;
label
  10;
var
  wait_val: integer32;
  handle: dir_$handle_ptr_t;
  found: boolean;
  i: integer;
begin
  repeat
    ml_$exclusion_start(dir_$mutex);
    handle := dir_$handle_free;
    if handle <> nil then
      exit;

    { the naming server's helper never waits }
    if proc1_$type[proc1_$current] = 9 then
      goto 10;

    { does the process hold a handle already? }
    found := false;
    for i := 0 to 31 do
      if (i in dir_$handle_in_use) and then
         (dir_$handle_tab[i].owner = proc1_$current) then begin
        found := true;
        exit;
      end;

    { then it may have the reserve handle }
    if found and then not (0 in dir_$handle_in_use) then begin
      handle := addr(dir_$handle_tab[0]);
      dir_$handle_in_use := dir_$handle_in_use + [0];
      goto 10;
    end;

    { wait for a free handle }
    wait_val := dir_$wt_for_hdnl_ec.value + 1;
    dir_$hndl_waits := dir_$hndl_waits + 1;
    ml_$exclusion_stop(dir_$mutex);
    discard(ec_$wait(addr(dir_$wt_for_hdnl_ec), addr(ec_$nil_ec),
                     addr(ec_$nil_ec), wait_val, 0, 0));
  until false;

  { take the free list's head }
  dir_$handle_in_use := dir_$handle_in_use + [handle^.slot_index];
  dir_$handle_free := handle^.next;

10:
  ml_$exclusion_stop(dir_$mutex);
  dir_$alloc_handle := handle;

  if handle <> nil then
    with handle^ do begin
      owner := proc1_$current;
      lock_mode := 0;
      split_busy := false;
      map.info.active := false;
      max_slots := 2;
      lock_entry := nil;
    end;
end;
