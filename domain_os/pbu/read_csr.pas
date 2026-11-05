{ PBU_$READ_CSR - read a PBU unit's CSR.

  Image addresses:
    sau3  0x00E5A054  PBU_$READ_CSR
    sau5  0x00E5A500  PBU_$READ_CSR
    sau6  0x78062154  PBU_$READ_CSR
    sau7  0x3C46ACF0  PBU_$READ_CSR
    sau8  0x03C629E8  PBU_$READ_CSR

  - The CSR is passed by address, and its address is the one read: a
    word with word_access, else a byte (moved down from the data word's
    high half, where TESTPAGE's byte read leaves it).

  Status stored:
    pbu_access_csr's status: the CSR was read, or not
}

procedure pbu_$read_csr(in unit: integer; in csr: univ pbu_$buffer_t;
                        out data: pinteger; in word_access: boolean;
                        out status: status_$t);
var
  kind: integer;
begin
  if word_access then
    kind := pbu_csr_read_word
  else
    kind := pbu_csr_read_byte;
  pbu_access_csr(unit, linteger(addr(csr)), data, kind, status);
  if not word_access then
    data := data div 256;
end;
