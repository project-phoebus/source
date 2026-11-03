{ pbu_access_csr - read or write a PBU unit's CSR.

  Image addresses:
    sau3  0x00E59FCC  pbu_access_csr (module-local)
    sau5  0x00E5A478  pbu_access_csr (module-local)
    sau8  0x03C6293C  pbu_access_csr (module-local)

  - The CSR must be in the unit's CSR page (its first page only) or its
    controller memory.  kind is TESTPAGE's: 0 a byte read, 1 a word
    read, 2 a byte write, 3 a word write.
  - The access is made under TESTPAGE; on the AT bus
    (`pbu_atbus_units') directly, a byte through the high half of a
    word.

  Status stored:
    pbu_check_unit's status: the access was made, or the unit is not
      the caller's
    status_$pbu_csr_not_in_csr_page: the CSR is in neither
    status_$pbu_csr_bus_timeout: the access caused a bus error (not on
      the AT bus)
}

procedure pbu_access_csr(unit: integer; csr: linteger;
                         var data: univ pbu_$csr_data_t; kind: integer;
                         out status: status_$t);
  internal;
%if pbu_atbus_units %then
type
  csr_byte_ptr_t = ^char;
  csr_word_ptr_t = ^integer;
%endif
var
  dcte: pbu_$dcte_ptr_t;
  location: univ_ptr;
%if pbu_atbus_units %then
  pair: pbu_$csr_data_t;
%endif
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
%if pbu_atbus_units %then
  case kind of
    pbu_csr_read_byte: begin
      pair.high := csr_byte_ptr_t(location)^;
      data.word := pair.word;
    end;
    pbu_csr_read_word: begin
      data.word := csr_word_ptr_t(location)^;
    end;
    pbu_csr_write_byte: begin
      pair.word := data.word;
      csr_byte_ptr_t(location)^ := pair.high;
    end;
    pbu_csr_write_word: begin
      csr_word_ptr_t(location)^ := data.word;
    end;
  end;
%else
  if not testpage(kind, location, data) then
    status.all := status_$pbu_csr_bus_timeout;
%endif
end;
