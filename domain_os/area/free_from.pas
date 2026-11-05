{ AREA_$FREE_FROM - delete every area made for one remote UID.

  Image addresses:
    sau2  0x00E07FC6  AREA_$FREE_FROM
    sau4  0x0F8082B2  AREA_$FREE_FROM
    sau6  0x780084F0  AREA_$FREE_FROM
    sau7  0x3C408DE4  AREA_$FREE_FROM
    sau9  0x3C4095E4  AREA_$FREE_FROM

  - Under the area lock the UID's chain record (bucket UID mod 11) has
    each entry deleted without unlinking (a failure crashes the system)
    and put on AREA_$FREE_LIST; the record is unlinked and freed.

  Status stored: none.
}

procedure area_$free_from(remote_uid: linteger);
var
  status: status_$t;
  bucket: pinteger;
  hash_entry: area_$uid_hash_ptr_t;
  prev_hash: area_$uid_hash_ptr_t;
  entry: area_$entry_ptr_t;
  next_entry: area_$entry_ptr_t;
begin
  ml_$lock(ml_$area_lock);
  bucket := remote_uid mod 11;
  hash_entry := area_$uid_hash[bucket];
  prev_hash := nil;

  { the UID's chain record }
  while hash_entry <> nil do begin
    if hash_entry^.first_entry^.remote_uid = remote_uid then
      exit;
    prev_hash := hash_entry;
    hash_entry := hash_entry^.next;
  end;

  if hash_entry <> nil then begin
    entry := hash_entry^.first_entry;
    while entry <> nil do begin
      next_entry := entry^.next;
      area_$internal_delete(entry^, entry^.area_id, status, false);
      if status.all <> status_$ok then
        crash_system(status);
      entry^.prev := nil;
      entry^.next := area_$free_list;
      area_$free_list := entry;
      entry := next_entry;
      area_$n_free := area_$n_free + 1;
    end;
    hash_entry^.first_entry := nil;
    if prev_hash = nil then
      area_$uid_hash[bucket] := hash_entry^.next
    else
      prev_hash^.next := hash_entry^.next;
    hash_entry^.next := area_$uid_hash_free;
    area_$uid_hash_free := hash_entry;
  end;

  ml_$unlock(ml_$area_lock);
end;
