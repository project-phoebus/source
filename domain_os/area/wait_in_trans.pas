{ area_$wait_in_trans - drop the area lock until area_$in_trans_ec advances.

  Image addresses:
    sau2  0x00E07742  area_$wait_in_trans (module-local)
    sau4  0x0F807A30  area_$wait_in_trans (module-local)
    sau9  0x3C408D72  area_$wait_in_trans (module-local)

  Assume we're called with the area lock held.

  - The next value of AREA_$IN_TRANS_EC is read, the lock released while
    the eventcount reaches it, and taken again.

  Status stored: none.
}

procedure area_$wait_in_trans; internal;
var
  wait_val: integer32;
begin
  wait_val := area_$in_trans_ec.value + 1;
  ml_$unlock(ml_$area_lock);
  discard(ec_$waitn(addr(area_$in_trans_ec), wait_val, 1));
  ml_$lock(ml_$area_lock);
end;
