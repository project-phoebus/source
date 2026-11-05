{ COLOR6_$DEVICE_INFO - return the unit's page and the board's sharing.

  Image addresses:
    sau7  0x3C483B60  COLOR6_$DEVICE_INFO

  - arg_1 is not read; length is the answer's, 4 bytes.

  Status stored:
    status_$ok: always
}

procedure color6_$device_info(dcte: color6_$dcte_ptr_t; arg_1: integer32;
                              out info: color6_$dev_info_t;
                              out length: integer32;
                              out status: status_$t);
  options(val_param);
begin
  status.all := status_$ok;
  info.page := dcte^.cnum;
  info.shared := color6_shared;
  length := 4;
end;
