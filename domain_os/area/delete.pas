{ AREA_$DELETE - delete an area by its handle.

  Image addresses:
    sau2  0x00E07C22  AREA_$DELETE
    sau4  0x0F807F0E  AREA_$DELETE
    sau6  0x78008152  AREA_$DELETE
    sau7  0x3C408A46  AREA_$DELETE
    sau9  0x3C409246  AREA_$DELETE

  - Under the area lock, after waiting out any operation in transition,
    the entry is marked in transition; the area is then deleted with its
    entry returned to the free list (area_$internal_delete).

  Status stored:
    area_$internal_delete's status: the area was deleted, or not
    status_$area_not_active: an id outside 1..AREA_$N_AREAS, an entry
      not active or of another generation
    status_$area_not_owner: a local area of another address space (the
      caller not address space 0)
}

procedure area_$delete(handle: area_$handle_t; out status: status_$t);
var
  status_l: status_$t;
  entry: area_$entry_ptr_t;
begin
  if (handle.area_id = 0) or else (handle.area_id > area_$n_areas) then
  begin
    status.all := status_$area_not_active;
    return;
  end;

  entry := addr(areas[handle.area_id]);
  ml_$lock(ml_$area_lock);
  while area_$f_in_trans in entry^.flags do
    area_$wait_in_trans;

  if (not (area_$f_active in entry^.flags)) or else
     (entry^.generation <> handle.generation) then
    status_l.all := status_$area_not_active
  else if (entry^.remote_uid = 0) and then (proc1_$as_id <> 0) and then
          (proc1_$as_id <> entry^.owner_asid) then
    status_l.all := status_$area_not_owner
  else begin
    entry^.flags := entry^.flags + [area_$f_in_trans];
    ml_$unlock(ml_$area_lock);
    area_$internal_delete(entry^, handle.area_id, status_l, true);
    ec_$advance(area_$in_trans_ec);
    status := status_l;
    return;
  end;

  ml_$unlock(ml_$area_lock);
  status := status_l;
end;
