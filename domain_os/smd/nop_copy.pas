{ SMD_$NOP_COPY - the default for a device's font copy into hidden memory.

  Image addresses:
    sau7  0x3C421A0E  SMD_$NOP_COPY
    sau9  0x3C420126  SMD_$NOP_COPY

  - Succeeds and returns 0; the font is not read.

  Status stored:
    status_$ok: always
}

[section(wired_proc, wired_data)]
function smd_$nop_copy(dcte: univ_ptr; var font_ptr: univ_ptr;
                       out status: status_$t): integer;
  options(val_param);
begin
  status.all := status_$ok;
  smd_$nop_copy := 0;
end;
