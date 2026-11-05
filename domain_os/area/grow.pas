{ AREA_$GROW - set an area's sizes, through its handle.

  Image addresses:
    sau2  0x00E08BE8  AREA_$GROW
    sau4  0x0F8090FC  AREA_$GROW
    sau6  0x780092E2  AREA_$GROW
    sau7  0x3C409BDA  AREA_$GROW
    sau9  0x3C40A3DA  AREA_$GROW

  - Under the area lock, after waiting out any operation in transition,
    the entry is marked in transition and area_$resize called (is_grow
    1) with the lock released; the mark is then cleared.

  Status stored:
    area_$resize's status: the sizes were set, or not
    status_$area_not_active: an id outside 1..AREA_$N_AREAS, an entry
      not active or of another generation
    status_$area_not_owner: a local area of another address space (the
      caller not address space 0)
}

procedure area_$grow(handle: area_$handle_t; virt_size: linteger;
                     commit_size: linteger; out status: status_$t);
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
    area_$resize(handle.area_id, entry^, virt_size, commit_size, 1,
                 status_l);
    ml_$lock(ml_$area_lock);
    entry^.flags := entry^.flags - [area_$f_in_trans];
    ec_$advance(area_$in_trans_ec);
  end;

  ml_$unlock(ml_$area_lock);
  status := status_l;
end;
