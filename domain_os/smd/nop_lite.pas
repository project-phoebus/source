{ SMD_$NOP_LITE - the default for a device's lights: nothing.

  Image addresses:
    sau9  0x3C420144  SMD_$NOP_LITE

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure smd_$nop_lite(dcte: univ_ptr; pattern: pinteger;
                        y_pos: pinteger);
  options(val_param);
begin
end;
