{ area_$wait_pite_in_trans - drop the AST lock until
  area_$pite_in_trans_ec advances.

  Image addresses:
    sau2  0x00E0778E  area_$wait_pite_in_trans (module-local)
    sau4  0x0F807A7C  area_$wait_pite_in_trans (module-local)
    sau9  0x3C408DBE  area_$wait_pite_in_trans (module-local)

  Assume we're called with the AST lock held.

  - The next value of AREA_$PITE_IN_TRANS_EC is read, the lock released
    while the eventcount reaches it, and taken again.

  Status stored: none.
}

procedure area_$wait_pite_in_trans; internal;
var
  wait_val: integer32;
begin
  wait_val := area_$pite_in_trans_ec.value + 1;
  ml_$unlock(ml_$ast_lock);
  discard(ec_$waitn(addr(area_$pite_in_trans_ec), wait_val, 1));
  ml_$lock(ml_$ast_lock);
end;
