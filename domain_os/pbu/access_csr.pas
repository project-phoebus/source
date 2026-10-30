{ pbu_access_csr - read or write a PBU unit's CSR under TESTPAGE.

  Image addresses:
    sau5  0x00E5A478  pbu_access_csr (module-local)

  - The CSR must be in the unit's CSR page (its first page only) or its
    controller memory.  kind is TESTPAGE's: 0 a byte read, 1 a word
    read, 2 a byte write, 3 a word write.

  Status stored:
    pbu_check_unit's status: the access was made, or the unit is not
      the caller's
    status_$pbu_csr_not_in_csr_page: the CSR is in neither
    status_$pbu_csr_bus_timeout: the access caused a bus error
}

procedure pbu_access_csr(unit: integer; csr: linteger;
                         var data: univ char; kind: integer;
                         out status: status_$t);
  internal;
var
  dcte: pbu_$dcte_ptr_t;
  location: univ_ptr;
begin
  dcte := pbu_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  if not (((csr >= dcte^.csr_va) and then (dcte^.csr_va + 1024 > csr))
          or else ((dcte^.assoc_va + dcte^.assoc_length > csr) and then
                   (dcte^.assoc_length <> 0) and then
                   (csr >= dcte^.assoc_va))) then begin
    status.all := status_$pbu_csr_not_in_csr_page;
    return;
  end;
  location := univ_ptr(csr);
  if not testpage(kind, location, data) then
    status.all := status_$pbu_csr_bus_timeout;
end;
