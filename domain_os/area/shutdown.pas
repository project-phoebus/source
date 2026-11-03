{ AREA_$SHUTDOWN - delete every area at shutdown.

  Image addresses:
    sau2  0x00E07F0E  AREA_$SHUTDOWN
    sau4  0x0F8081FA  AREA_$SHUTDOWN
    sau9  0x3C40952C  AREA_$SHUTDOWN

  - Every address space's areas are freed (AREA_$FREE_ASID for 0..57);
    then, under the area lock, every UID chain record's entries are
    deleted and freed and the record returned to the free records.
  - The buckets are not cleared.

  Status stored: none.
}

procedure area_$shutdown;
var
  status: status_$t;
  i: integer;
  hash_entry: area_$uid_hash_ptr_t;
  next_hash: area_$uid_hash_ptr_t;
  entry: area_$entry_ptr_t;
  next_entry: area_$entry_ptr_t;
begin
  { every address space's areas }
  for i := 0 to 57 do
    area_$free_asid(i);

  ml_$lock(ml_$area_lock);

  { the remote areas, by their UID chains }
  for i := 0 to 10 do begin
    hash_entry := area_$uid_hash[i];
    while hash_entry <> nil do begin
      entry := hash_entry^.first_entry;
      while entry <> nil do begin
        next_entry := entry^.next;
        entry^.first_bste := -1;
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
      next_hash := hash_entry^.next;
      hash_entry^.next := area_$uid_hash_free;
      area_$uid_hash_free := hash_entry;
      hash_entry := next_hash;
    end;
  end;

  ml_$unlock(ml_$area_lock);
end;
