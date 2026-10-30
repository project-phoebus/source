{ WIN_$ERROR_QUE - the error queue entry: the Winchester driver has none.

  Image addresses:
    sau2  0x00E19D54  WIN_$ERROR_QUE
    sau5  0x00E1A148  WIN_$ERROR_QUE

  - The result byte is cleared.

  Status stored: none.
}

procedure win_$error_que(in vol: disk_$volume_t; is_timeout: integer;
                         out result: boolean);
begin
  result := false;
end;
