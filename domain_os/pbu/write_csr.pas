{ PBU_$WRITE_CSR - write a PBU unit's CSR.

  Image addresses:
    sau3  0x00E5A0AA  PBU_$WRITE_CSR
    sau5  0x00E5A556  PBU_$WRITE_CSR

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
    kind := 3;
    value := data;
  end
  else begin
    kind := 2;
    value := data * 256;
  end;
  pbu_access_csr(unit, linteger(addr(csr)), value, kind, status);
end;
