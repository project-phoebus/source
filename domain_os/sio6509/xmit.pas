{ SIO6509_$XMIT - the console line's transmit entry: an empty procedure.

  Image addresses:
    sau2  0x00E1D586  SIO6509_$XMIT
    sau3  0x00E1C6FA  SIO6509_$XMIT

  - The 6509 console line transmits through DTTY, not through this
    entry.
  - A fragment of the SIO_IO module (sio6509/README.md).

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure sio6509_$xmit(in chan: sio6509_$chan_t; ch: char);
  options(val_param);
begin
end;
