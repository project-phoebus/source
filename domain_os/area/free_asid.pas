{ AREA_$FREE_ASID - delete every area an address space owns.

  Image addresses:
    sau2  0x00E07E80  AREA_$FREE_ASID
    sau4  0x0F80816C  AREA_$FREE_ASID
    sau6  0x780083AA  AREA_$FREE_ASID
    sau7  0x3C408C9E  AREA_$FREE_ASID
    sau9  0x3C40949E  AREA_$FREE_ASID

  - Under the area lock each entry of the address space's list loses its
    first BSTE (16#FFFF), is deleted without unlinking (a failure
    crashes the system) and goes on AREA_$FREE_LIST; the list's head is
    cleared.

  Status stored: none.
}

procedure area_$free_asid(asid: integer);
var
  status: status_$t;
  entry: area_$entry_ptr_t;
  next: area_$entry_ptr_t;
begin
  ml_$lock(ml_$area_lock);
  entry := area_$asid_list[asid];

  while entry <> nil do begin
    next := entry^.next;
    entry^.first_bste := -1;
    area_$internal_delete(entry^, entry^.area_id, status, false);
    if status.all <> status_$ok then
      crash_system(status);
    entry^.prev := nil;
    entry^.next := area_$free_list;
    area_$free_list := entry;
    entry := next;
    area_$n_free := area_$n_free + 1;
  end;

  area_$asid_list[asid] := nil;
  ml_$unlock(ml_$area_lock);
end;
