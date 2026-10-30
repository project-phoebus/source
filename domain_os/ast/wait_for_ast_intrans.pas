{ AST_$WAIT_FOR_AST_INTRANS - wait for an ASTE in transition.

  Image addresses:
    sau2  0x00E00C54  AST_$WAIT_FOR_AST_INTRANS
    sau9  0x3C402034  AST_$WAIT_FOR_AST_INTRANS

  Assume we're called with the AST lock held.

  - The lock is dropped while the routine waits for the next advance of
    AST_$AST_IN_TRANS_EC, and taken again.

  Status stored: none.
}

procedure ast_$wait_for_ast_intrans;
var
  wait_val: integer32;
begin
  wait_val := ast_$ast_in_trans_ec.value + 1;

  ml_$unlock(ml_$ast_lock);
  discard(ec_$waitn(addr(ast_$ast_in_trans_ec), wait_val, 1));
  ml_$lock(ml_$ast_lock);
end;
