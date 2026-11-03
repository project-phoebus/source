{ pmap_$wait_in_transit - drop the PMAP lock until a page write completes.

  Image addresses:
    sau2  0x00E12D38  pmap_$wait_in_transit
    sau4  0x0F813670  pmap_$wait_in_transit (module-local)
    sau9  0x3C4150B4  pmap_$wait_in_transit

  Assume we're called with the PMAP lock held.

  - Waits for the next advance of AST_$PMAP_IN_TRANS_EC with the lock
    released, and returns with it held again.

  Status stored: none.
}

procedure pmap_$wait_in_transit; internal;
var
  wait_val: integer32;
begin
  wait_val := ast_$pmap_in_trans_ec.value + 1;
  ml_$unlock(ml_$pmap_lock);
  discard(ec_$waitn(addr(ast_$pmap_in_trans_ec), wait_val, 1));
  ml_$lock(ml_$pmap_lock);
end;
