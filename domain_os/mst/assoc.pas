{ MST_$ASSOC - associate a physical page with the page of a virtual
  address.

  Image addresses:
    sau9  0x3C410544  MST_$ASSOC

  - The address's segment is activated and wired (mst_$va_to_aste), the
    page put in its page map (AST_$PMAP_ASSOC), and the segment unwired.

  Status stored:
    mst_$va_to_aste's status: the segment has no ASTE
    AST_$PMAP_ASSOC's status: otherwise
}

procedure mst_$assoc(in va: integer32; in ppn: integer32;
                     out status: status_$t);
var
  page: integer;
  aste: ast_$aste_ptr_t;
begin
  aste := mst_$va_to_aste(va, page, status);
  if aste <> nil then begin
    ast_$pmap_assoc(aste, page, ppn, true, false, status);
    aste^.wire_count := aste^.wire_count - 1;
  end;
end;
