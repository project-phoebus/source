{ SMD_$NOP_SHAREDEV - the default for a device's sharing.

  Image addresses:
    sau9  0x3C4743E6  SMD_$NOP_SHAREDEV

  - A device without it refuses.

  Status stored:
    smd_$access_denied: always
}

procedure smd_$nop_sharedev(dcte: univ_ptr; arg_1: integer;
                            out status: status_$t);
  options(val_param);
begin
  status.all := smd_$access_denied;
end;
