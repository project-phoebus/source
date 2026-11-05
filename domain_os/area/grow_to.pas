{ AREA_$GROW_TO - set an area's sizes, through its index.

  Image addresses:
    sau2  0x00E08CEA  AREA_$GROW_TO
    sau4  0x0F8091FE  AREA_$GROW_TO
    sau6  0x780093E4  AREA_$GROW_TO
    sau7  0x3C409CDC  AREA_$GROW_TO
    sau9  0x3C40A4DC  AREA_$GROW_TO

  - AREA_$GROW with the area's index for a handle and no active or
    generation test.

  Status stored:
    area_$resize's status: the sizes were set, or not
    status_$area_not_active: an index outside 1..AREA_$N_AREAS
    status_$area_not_owner: a local area of another address space
}

procedure area_$grow_to(area_index: pinteger; virt_size: linteger;
                        commit_size: linteger; out status: status_$t);
var
  status_l: status_$t;
  entry: area_$entry_ptr_t;
begin
  if (area_index = 0) or else (area_index > area_$n_areas) then begin
    status.all := status_$area_not_active;
    return;
  end;

  ml_$lock(ml_$area_lock);
  entry := addr(areas[area_index]);
  while area_$f_in_trans in entry^.flags do
    area_$wait_in_trans;

  if (entry^.remote_uid = 0) and then (proc1_$as_id <> 0) and then
     (proc1_$as_id <> entry^.owner_asid) then
    status_l.all := status_$area_not_owner
  else begin
    entry^.flags := entry^.flags + [area_$f_in_trans];
    ml_$unlock(ml_$area_lock);
    area_$resize(area_index, entry^, virt_size, commit_size, 1, status_l);
    ml_$lock(ml_$area_lock);
    entry^.flags := entry^.flags - [area_$f_in_trans];
    ec_$advance(area_$in_trans_ec);
  end;

  ml_$unlock(ml_$area_lock);
  status := status_l;
end;
