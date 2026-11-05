{ SMD_$NOP_BLINK - the default for a device's cursor blink: nothing.

  Image addresses:
    sau7  0x3C421A1E  SMD_$NOP_BLINK
    sau9  0x3C420136  SMD_$NOP_BLINK

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure smd_$nop_blink(dcte: univ_ptr; var blink: smd_time_com_t;
                         var hw: smd_display_hw_t);
  options(val_param);
begin
end;
