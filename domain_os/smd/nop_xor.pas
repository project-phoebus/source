{ SMD_$NOP_XOR - the default for a device's cursor drawing.

  Image addresses:
    sau9  0x3C420138  SMD_$NOP_XOR

  - Draws nothing and returns true.

  Status stored: none.
}

[section(wired_proc, wired_data)]
function smd_$nop_xor(dcte: univ_ptr; cursor_num: integer;
                      pos: smd_$pos_t;
                      in limits: smd_$window_limits_t;
                      flag_1: boolean; flag_2: boolean): boolean;
  options(val_param);
begin
  smd_$nop_xor := true;
end;
