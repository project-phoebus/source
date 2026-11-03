{ SIO6509_$SET_LINE - the console line's set-line entry: always
  "invalid option".

  Image addresses:
    sau2  0x00E72656  SIO6509_$SET_LINE
    sau3  0x00E73C52  SIO6509_$SET_LINE

  - The routine changes nothing.
  - A fragment of the SIO_IO module (sio6509/README.md).

  Status stored:
    status_$sio_invalid_option: always
}

[section(procedure$, data$)]
procedure sio6509_$set_line(in chan: sio6509_$chan_t; in params: sio_$params_t;
                            change_mask: integer32; out status: status_$t);
  options(val_param);
begin
  status.all := status_$sio_invalid_option;
end;
