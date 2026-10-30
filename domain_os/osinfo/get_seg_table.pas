{ OSINFO_$GET_SEG_TABLE - copy the active segment table or its page maps
  to the caller.

  Image addresses:
    sau2  0x00E5C5C4  OSINFO_$GET_SEG_TABLE

  - The total is AST_$SIZE_AST; the smaller of it and the maximum is
    copied, ASTEs (20 bytes) for type 2, AST_PMAPS entries (128 bytes)
    for type 1, nothing for another type or a maximum of 0.

  Status stored:
    status_$ok: the whole table was copied
    osinfo_$array_toosmall: the maximum is the smaller
}

procedure osinfo_$get_seg_table(in table_type: integer;
                                out buffer: univ osinfo_$seg_buf_t;
                                in max_entries: integer;
                                out actual_entries: integer;
                                out total_entries: integer;
                                out status: status_$t);
var
  i: integer;
begin
  status.all := status_$ok;
  total_entries := ast_$size_ast;
  if max_entries = 0 then
    return;

  if max_entries >= ast_$size_ast then
    actual_entries := ast_$size_ast
  else begin
    actual_entries := max_entries;
    status.all := osinfo_$array_toosmall;
  end;

  if table_type = 2 then begin
    for i := 1 to actual_entries do
      buffer.aste[i] := ast[i];
  end
  else if table_type = 1 then
    for i := 1 to actual_entries do
      buffer.pmap[i] := ast_pmaps[i];
end;
