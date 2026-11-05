{ ast_$wait_for_page_transition - wait for a page in transition.

  Image addresses:
    sau2  0x00E00C08  ast_$wait_for_page_transition (module-local)
    sau4  0x0F801008  ast_$wait_for_page_transition (module-local)
    sau6  0x780013E8  ast_$wait_for_page_transition (module-local)
    sau7  0x3C4017E8  ast_$wait_for_page_transition (module-local)
    sau9  0x3C401FE8  ast_$wait_for_page_transition (module-local)

  Assume we're called with the PMAP lock held.

  - Waits for the next advance of AST_$PMAP_IN_TRANS_EC with the lock
    released, and returns with it held again.

  Status stored: none.
}

procedure ast_$wait_for_page_transition; internal;
var
  wait_val: integer32;
begin
  wait_val := ast_$pmap_in_trans_ec.value + 1;

  ml_$unlock(ml_$pmap_lock);
  discard(ec_$waitn(addr(ast_$pmap_in_trans_ec), wait_val, 1));
  ml_$lock(ml_$pmap_lock);
end;
