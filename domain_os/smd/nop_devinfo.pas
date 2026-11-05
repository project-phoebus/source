{ SMD_$NOP_DEVINFO - the default for a device's information.

  Image addresses:
    sau7  0x3C480CB2  SMD_$NOP_DEVINFO
    sau9  0x3C4743D2  SMD_$NOP_DEVINFO

  - Clears the third argument.

  Status stored:
    status_$ok: always
}

procedure smd_$nop_devinfo(dcte: univ_ptr; arg_1: integer32;
                           var arg_2: integer32;
                           out arg_3: integer32;
                           out status: status_$t);
  options(val_param);
begin
  arg_3 := 0;
  status.all := status_$ok;
end;
