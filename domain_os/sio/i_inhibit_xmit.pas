{ SIO_$I_INHIBIT_XMIT - stop or resume a serial line's transmitter.

  Image addresses:
    sau2  0x00E1C9CE  SIO_$I_INHIBIT_XMIT
    sau4  0x0F81DBE2  SIO_$I_INHIBIT_XMIT
    sau6  0x7801E8C4  SIO_$I_INHIBIT_XMIT
    sau7  0x3C420BB0  SIO_$I_INHIBIT_XMIT

  - Inhibiting sets the inhibited state member (2); resuming clears it
    and lets SIO_$I_TSTART send what is queued.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure sio_$i_inhibit_xmit(desc: sio_$desc_ptr_t; inhibit: boolean);
  options(val_param);
begin
  if inhibit then
    desc^.state := desc^.state + [2]
  else begin
    desc^.state := desc^.state - [2];
    sio_$i_tstart(desc);
  end;
end;
