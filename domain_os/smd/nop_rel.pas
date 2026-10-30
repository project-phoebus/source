{ SMD_$NOP_REL - the default for a device's display release: nothing.

  Image addresses:
    sau9  0x3C420142  SMD_$NOP_REL

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure smd_$nop_rel(dcte: univ_ptr; var hw: smd_display_hw_t);
  options(val_param);
begin
end;
