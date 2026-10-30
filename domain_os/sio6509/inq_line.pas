{ SIO6509_$INQ_LINE - the console line's inquire-line entry.

  Image addresses:
    sau2  0x00E72668  SIO6509_$INQ_LINE

  - When the mask asks about the modem inputs (bits 7 and 8, 16#180),
    both are reported asserted (bits 1 and 2 of flags1): the console
    line has none.
  - A fragment of the SIO_IO module (sio6509/README.md).

  Status stored:
    status_$ok: always
}

[section(procedure$, data$)]
procedure sio6509_$inq_line(in chan: sio6509_$chan_t; in out params: sio_$params_t;
                            mask: integer32; out status: status_$t);
  options(val_param);
begin
  status.all := status_$ok;

  if (mask & 16#180) <> 0 then
    params.flags1 := params.flags1 + [1, 2];
end;
