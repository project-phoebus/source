{ ast_$release_aote - put an AOTE back on the free list.

  Image addresses:
    sau2  0x00E00F7C  ast_$release_aote (module-local)
    sau4  0x0F80137E  ast_$release_aote (module-local)
    sau9  0x3C40235E  ast_$release_aote (module-local)

  - The entry's UID becomes UID_$NIL, its remote flag and volume index
    are cleared, and it is pushed on the free list, marked in transition
    (the free marker); the AST in-transition eventcount is advanced.

  Status stored: none.
}

procedure ast_$release_aote(var aote: ast_$aote_t); internal;
begin
  aote.uid := uid_$nil;

  aote.loc.remote := false;
  aote.vol_index := 0;

  aote.hash_next := ast_$free_aote_head;
  ast_$free_aote_head := addr(aote);

  aote.flags := aote.flags + [7];

  ec_$advance(ast_$ast_in_trans_ec);
  ast_$free_aotes := ast_$free_aotes + 1;
end;
