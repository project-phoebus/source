{ AST_$GET_DISM_SEQN - the dismount sequence number.

  Image addresses:
    sau2  0x00E01388  AST_$GET_DISM_SEQN
    sau9  0x3C402784  AST_$GET_DISM_SEQN

  - The module's dismount sequence number (+0x404 of the AST_ block),
    which AST_$DISMOUNT advances on each dismount.

  Status stored: none.
}

function ast_$get_dism_seqn: integer32;
begin
  ast_$get_dism_seqn := ast_$dism_seqn;
end;
