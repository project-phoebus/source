{ AST_$FREE_ASTE - return an ASTE to the free list.

  Image addresses:
    sau2  0x00E00FBC  AST_$FREE_ASTE
    sau9  0x3C40239E  AST_$FREE_ASTE

  - The count of its kind (area, remote, local) is lowered, its AOTE
    link dropped, and it is pushed on the free list, marked in
    transition (the free marker); the AST in-transition eventcount is
    advanced.

  Status stored: none.
}

procedure ast_$free_aste(var aste: ast_$aste_t);
begin
  if 12 in aste.flags then
    ast_$aste_area_cnt := ast_$aste_area_cnt - 1
  else if 11 in aste.flags then
    ast_$aste_r_cnt := ast_$aste_r_cnt - 1
  else
    ast_$aste_l_cnt := ast_$aste_l_cnt - 1;

  aste.aote := nil;
  aste.next := ast_$free_aste_head;
  ast_$free_aste_head := addr(aste);

  aste.flags := aste.flags + [15];
  ast_$free_astes := ast_$free_astes + 1;

  ec_$advance(ast_$ast_in_trans_ec);
end;
