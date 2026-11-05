{ SMD_$NOP_PUT - the default for a device's character output: nothing.

  Image addresses:
    sau7  0x3C421A2E  SMD_$NOP_PUT
    sau9  0x3C420146  SMD_$NOP_PUT

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure smd_$nop_put(dcte: univ_ptr; var arg_1: integer32;
                       c: integer);
  options(val_param);
begin
end;
