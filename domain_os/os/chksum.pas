{ OS_$CHKSUM - the kernel's checksum request (a stub).

  Image addresses:
    sau2  0x00E6D698  OS_$CHKSUM
    sau3  0x00E6DAA0  OS_$CHKSUM
    sau4  0x0F87721C  OS_$CHKSUM
    sau6  0x7807629C  OS_$CHKSUM
    sau7  0x3C480BC4  OS_$CHKSUM
    sau8  0x03C76A88  OS_$CHKSUM

  - enable is cleared; the first three arguments are not read.

  Status stored:
    status_$ok: always
}

procedure os_$chksum(in param_1: univ integer32;
                     in param_2: univ integer32;
                     in param_3: univ integer32;
                     out enable: boolean; out status_ret: status_$t);
begin
  status_ret.all := status_$ok;
  enable := false;
end;
