{ area_$internal_create - take a free area entry and set it up.

  Image addresses:
    sau2  0x00E077DA  area_$internal_create (module-local)
    sau4  0x0F807AC8  area_$internal_create (module-local)
    sau9  0x3C408E0A  area_$internal_create (module-local)

  - An entry is taken off AREA_$FREE_LIST (the table grown when it is
    empty), under the area lock for a local create, which also threads
    it onto its address space's list.
  - The entry is stamped (the remote UID, the owner, a new generation,
    the flags); with a diskless partner and alloc_remote, the partner
    gives backing store.  A non-empty area is then sized.
  - The result is the handle, or 0 (the entry given back) on a failure.

  Status stored:
    status_$ok: the area was created
    status_$area_none_free: no entry could be had
    rem_file_$create_area's or area_$resize's status: those failed
}

function area_$internal_create(virt_size: integer32; commit_size: integer32;
                               remote_uid: integer32; owner_asid: integer;
                               alloc_remote: integer; shared: boolean;
                               out status: status_$t): integer32;
  internal;
var
  handle: area_$handle_t;
  total_commit: integer32;
  temp_status: status_$t;
  local_volx: integer;
  e: area_$entry_ptr_t;
  remote_volx: integer;
  total_size: integer32;
begin
  area_$internal_create := 0;
  virt_size := (virt_size + 16#7FFF) & (-16#8000);

  if remote_uid = 0 then
    ml_$lock(ml_$area_lock);

  if area_$free_list = nil then
    if not area_$alloc_resources(16#60) then begin
      status.all := status_$area_none_free;
      if remote_uid = 0 then
        ml_$unlock(ml_$area_lock);
      return;
    end;

  e := area_$free_list;
  area_$free_list := e^.next;
  if remote_uid = 0 then begin
    e^.next := area_$asid_list[owner_asid];
    if e^.next <> nil then
      e^.next^.prev := e;
    e^.prev := nil;
    area_$asid_list[owner_asid] := e;
  end;

  e^.virt_size := 0;
  e^.commit_size := 0;
  e^.remote_uid := remote_uid;
  e^.remote_volx := 0;
  remote_volx := 0;
  e^.owner_asid := owner_asid;
  e^.generation := e^.generation + 1;
  e^.flags := [area_$f_active, area_$f_shared];
  if shared then
    e^.flags := e^.flags + [area_$f_reversed];
  e^.first_bste := -1;
  e^.caller_id := area_$next_caller_id;
  area_$next_caller_id := area_$next_caller_id + 1;
  area_$n_free := area_$n_free - 1;

  if remote_uid = 0 then
    ml_$unlock(ml_$area_lock);

  { the handle }
  handle.generation := e^.generation;
  handle.area_id := (linteger(e) - linteger(addr(areas))) div 48 + 1;
  e^.volx := 0;

  { the backing store }
  if area_$partner.low = 0 then
    e^.volx := cal_$boot_volx
  else if alloc_remote <> 0 then begin
    total_size := virt_size + ((virt_size - 1) div 16#40000 + 1) * 1024;
    total_commit := total_size - virt_size + commit_size;
    remote_volx := rem_file_$create_area(area_$partner, total_size,
                                         total_commit, e^.caller_id,
                                         shared, local_volx, status);
    if status.all <> status_$ok then begin
      area_$delete(handle, temp_status);
      return;
    end;
    if area_$partner_pkt_size = 0 then
      area_$partner_pkt_size := network_$get_pkt_size(area_$partner,
                                                      local_volx);
  end;
  e^.remote_volx := remote_volx;

  if virt_size <> 0 then
    area_$resize(handle.area_id, e^, virt_size, commit_size, 0, status)
  else
    status.all := status_$ok;

  if status.all = status_$ok then
    area_$internal_create := integer32(handle)
  else if remote_uid = 0 then
    area_$internal_delete(e^, handle.area_id, temp_status, true)
  else
    area_$internal_delete(e^, handle.area_id, temp_status, false);
end;
