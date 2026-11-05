{ AREA_$DELETE_FROM - delete an area on a remote caller's behalf.

  Image addresses:
    sau2  0x00E07D06  AREA_$DELETE_FROM
    sau4  0x0F807FF2  AREA_$DELETE_FROM
    sau6  0x78008236  AREA_$DELETE_FROM
    sau7  0x3C408B2A  AREA_$DELETE_FROM
    sau9  0x3C40932A  AREA_$DELETE_FROM

  - Under the area lock, after waiting out any operation in transition,
    an active entry of the given remote UID and caller id is deleted
    without unlinking, then taken out of its UID's chain and put on
    AREA_$FREE_LIST.
  - A request for any other entry is a duplicate or stale one, counted.

  Status stored:
    status_$ok: the area was deleted, or the request was stale
    status_$area_not_active: an id outside 1..AREA_$N_AREAS
    area_$internal_delete's status: the delete failed
}

procedure area_$delete_from(area_index: pinteger; remote_uid: linteger;
                            caller_id: integer32; out status: status_$t);
var
  entry: area_$entry_ptr_t;
  hash_entry: area_$uid_hash_ptr_t;
  prev_hash: area_$uid_hash_ptr_t;
  h: pinteger;
begin
  if (area_index = 0) or else (area_index > area_$n_areas) then begin
    status.all := status_$area_not_active;
    return;
  end;

  entry := addr(areas[area_index]);
  ml_$lock(ml_$area_lock);
  while area_$f_in_trans in entry^.flags do
    area_$wait_in_trans;

  if (not (area_$f_active in entry^.flags)) or else
     (remote_uid <> entry^.remote_uid) or else
     (caller_id <> entry^.caller_id) then begin
    status.all := status_$ok;
    area_$del_dup := area_$del_dup + 1;
  end
  else begin
    entry^.flags := entry^.flags + [area_$f_in_trans];
    ml_$unlock(ml_$area_lock);
    area_$internal_delete(entry^, area_index, status, false);
    ml_$lock(ml_$area_lock);

    if status.all = status_$ok then begin
      { the UID's chain record }
      h := remote_uid mod 11;
      hash_entry := area_$uid_hash[h];
      prev_hash := nil;
      while hash_entry <> nil do begin
        if hash_entry^.first_entry^.remote_uid = remote_uid then
          exit;
        prev_hash := hash_entry;
        hash_entry := hash_entry^.next;
      end;
      if hash_entry = nil then
        crash_system(status_$area_internal_error);

      { out of the record's list }
      if entry^.next <> nil then
        entry^.next^.prev := entry^.prev;
      if entry^.prev <> nil then
        entry^.prev^.next := entry^.next
      else
        hash_entry^.first_entry := entry^.next;

      { an empty record back to the pool }
      if hash_entry^.first_entry = nil then begin
        if prev_hash = nil then
          area_$uid_hash[h] := hash_entry^.next
        else
          prev_hash^.next := hash_entry^.next;
        hash_entry^.next := area_$uid_hash_free;
        area_$uid_hash_free := hash_entry;
      end;

      entry^.next := area_$free_list;
      entry^.prev := nil;
      area_$free_list := entry;
      area_$n_free := area_$n_free + 1;
    end;

    entry^.flags := entry^.flags - [area_$f_in_trans];
    ec_$advance(area_$in_trans_ec);
  end;

  ml_$unlock(ml_$area_lock);
end;
