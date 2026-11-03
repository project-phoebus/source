{ MST_$INSTALL_IOPPN - map an I/O page at a virtual address.

  Image addresses:
    sau8  0x03C0F4AE  MST_$INSTALL_IOPPN
    sau9  0x3C41059A  MST_$INSTALL_IOPPN

  - The address's segment is activated and wired (mst_$va_to_aste), the
    I/O page put in its page map (AST_$ASSOC_IOPPN, which wires the
    segment once more), and the first wiring dropped.

  Status stored:
    status_$mst_invalid_va_for_io_page: mst_$va_to_aste's status was
      status_$mst_asid_0_illegal
    mst_$va_to_aste's status: otherwise
}

procedure mst_$install_ioppn(ppn: integer32; va: integer32;
                             out status: status_$t);
  options(val_param);
var
  page: integer;
  aste: ast_$aste_ptr_t;
begin
  aste := mst_$va_to_aste(va, page, status);
  if aste = nil then begin
    if status.all = status_$mst_asid_0_illegal then
      status.all := status_$mst_invalid_va_for_io_page;
  end
  else begin
    ast_$assoc_ioppn(aste^, page, ppn);
    aste^.wire_count := aste^.wire_count - 1;
  end;
end;
