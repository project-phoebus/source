{ SMD_$INQ_MM_BLT - whether the display can BLT to and from main memory.

  Image addresses:
    sau2  0x00E6EE0C  SMD_$INQ_MM_BLT
    sau5  0x00E711BC  SMD_$INQ_MM_BLT

  - The result is false: this display cannot.

  Status stored:
    status_$ok: always
}

function smd_$inq_mm_blt(out status: status_$t): boolean;
begin
  status.all := status_$ok;
  smd_$inq_mm_blt := false;
end;
