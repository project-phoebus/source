{ AREA_$CREATE_FROM - create an area for a remote UID, or find it again.

  Image addresses:
    sau2  0x00E07A02  AREA_$CREATE_FROM
    sau4  0x0F807CF0  AREA_$CREATE_FROM
    sau6  0x78007F3E  AREA_$CREATE_FROM
    sau7  0x3C408832  AREA_$CREATE_FROM
    sau9  0x3C409032  AREA_$CREATE_FROM

  - Under the area lock an entry of the UID's hash chain (UID mod 11)
    with the same caller id is the answer; otherwise an area is created
    for the UID and entered at the front of its chain.  The result is
    the area's id.
  - The "no free resources" path does not assign the result.

  Status stored:
    status_$ok: the area was found or created
    area_$internal_create's status: the create failed
    status_$area_no_free_resources: no chain record was left (the new
      area deleted again)
}

function area_$create_from(remote_uid: linteger; virt_size: integer32;
                           commit_size: integer32; caller_id: integer32;
                           out status: status_$t): pinteger;
label
  10;
var
  handle: area_$handle_t;
  h: pinteger;
  chain: area_$uid_hash_ptr_t;
  e: area_$entry_ptr_t;
begin
  ml_$lock(ml_$area_lock);
  h := remote_uid mod 11;
  chain := area_$uid_hash[h];

  { the UID's chain }
  while chain <> nil do begin
    if chain^.first_entry^.remote_uid = remote_uid then
      exit;
    chain := chain^.next;
  end;

  { an entry for this caller }
  if chain <> nil then begin
    e := chain^.first_entry;
    while e <> nil do begin
      if e^.caller_id = caller_id then begin
        area_$create_from := (linteger(e) - linteger(addr(areas))) div 48 +
                             1;
        area_$cr_dup := area_$cr_dup + 1;
        status.all := status_$ok;
        goto 10;
      end;
      e := e^.next;
    end;
  end;

  handle := area_$handle_t(area_$internal_create(virt_size, commit_size,
                                                 remote_uid, 0, 0, false,
                                                 status));

  if status.all = status_$ok then begin
    if chain = nil then begin
      chain := area_$uid_hash_free;
      if chain = nil then begin
        area_$internal_delete(areas[handle.area_id], handle.area_id, status,
                              false);
        status.all := status_$area_no_free_resources;
        goto 10;
      end;
      area_$uid_hash_free := chain^.next;
      chain^.next := area_$uid_hash[h];
      area_$uid_hash[h] := chain;
      chain^.first_entry := nil;
    end;
    e := addr(areas[handle.area_id]);
    e^.caller_id := caller_id;
    if chain^.first_entry <> nil then
      chain^.first_entry^.prev := e;
    e^.next := chain^.first_entry;
    chain^.first_entry := e;
    e^.prev := nil;
  end;
  area_$create_from := handle.area_id;

10:
  ml_$unlock(ml_$area_lock);
end;
