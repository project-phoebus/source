{ SMD_$INQ_MM_BLT - whether the display can BLT to and from main memory.

  Image addresses:
    sau2  0x00E6EE0C  SMD_$INQ_MM_BLT
    sau4  0x0F879550  SMD_$INQ_MM_BLT
    sau5  0x00E711BC  SMD_$INQ_MM_BLT

  - The result is true with `blt_main_memory' (base/config.ins.pas),
    false otherwise.

  Status stored:
    status_$ok: always
}

function smd_$inq_mm_blt(out status: status_$t): boolean;
begin
  status.all := status_$ok;
%if blt_main_memory %then
  smd_$inq_mm_blt := true;
%else
  smd_$inq_mm_blt := false;
%endif
end;
