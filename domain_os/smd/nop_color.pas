{ SMD_$NOP_COLOR - the default for a device's color table.

  Image addresses:
    sau7  0x3C480CA4  SMD_$NOP_COLOR
    sau9  0x3C4743C4  SMD_$NOP_COLOR

  - Sets nothing.

  Status stored:
    status_$ok: always
}

procedure smd_$nop_color(dcte: univ_ptr; arg_1: integer;
                         arg_2: integer; var flag: boolean;
                         out status: status_$t);
  options(val_param);
begin
  status.all := status_$ok;
end;
