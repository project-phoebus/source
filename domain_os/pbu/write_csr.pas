{ PBU_$WRITE_CSR - write a PBU unit's CSR.

  Image addresses:
    sau3  0x00E5A0AA  PBU_$WRITE_CSR
    sau5  0x00E5A556  PBU_$WRITE_CSR
    sau6  0x780621AA  PBU_$WRITE_CSR
    sau7  0x3C46AD46  PBU_$WRITE_CSR
    sau8  0x03C62A3E  PBU_$WRITE_CSR

  - The CSR is passed by address, and its address is the one written:
    the data word with word_access, else its low byte (moved into the
    word's high half, where TESTPAGE's byte write takes it).

  Status stored:
    pbu_access_csr's status: the CSR was written, or not
}

procedure pbu_$write_csr(in unit: integer; in csr: univ pbu_$buffer_t;
                         in data: integer; in word_access: boolean;
                         out status: status_$t);
var
  kind: integer;
  value: integer;
begin
  if word_access then begin
    kind := pbu_csr_write_word;
    value := data;
  end
  else begin
    kind := pbu_csr_write_byte;
    value := data * 256;
  end;
  pbu_access_csr(unit, linteger(addr(csr)), value, kind, status);
end;
