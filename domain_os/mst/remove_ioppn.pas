{ MST_$REMOVE_IOPPN - unmap the I/O page at a virtual address.

  Image addresses:
    sau4  0x0F80EA54  MST_$REMOVE_IOPPN
    sau6  0x7800EB44  MST_$REMOVE_IOPPN
    sau7  0x3C41003E  MST_$REMOVE_IOPPN
    sau8  0x03C0F50A  MST_$REMOVE_IOPPN
    sau9  0x3C4105F6  MST_$REMOVE_IOPPN

  - The address's segment is activated and wired (mst_$va_to_aste); a
    failure crashes the system.  The I/O page leaves its page map
    (AST_$REMOVE_IOPPN, which unwires the segment once) and the
    segment's wiring is dropped.

  Status stored: none.
}

procedure mst_$remove_ioppn(va: integer32); options(val_param);
var
  status: status_$t;
  page: integer;
  aste: ast_$aste_ptr_t;
begin
  aste := mst_$va_to_aste(va, page, status);
  if status.all <> status_$ok then
    crash_system(status);
  ast_$remove_ioppn(aste^, page);
  aste^.wire_count := aste^.wire_count - 1;
end;
