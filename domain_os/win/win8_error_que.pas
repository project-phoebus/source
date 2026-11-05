{ WIN8_$ERROR_QUE - the error queue entry: the driver has none.

  Image addresses:
    sau7  0x3C41D8AA  WIN8_$ERROR_QUE
    sau8  0x03C1AED6  WIN8_$ERROR_QUE

  - The result byte is cleared.

  Status stored: none.
}

procedure win8_$error_que(in vol: disk_$volume_t; is_timeout: integer;
                          out result: boolean);
  options(val_param);
begin
  result := false;
end;
