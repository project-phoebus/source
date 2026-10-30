{ SIO_$I_XMIT_DONE - a character has been sent on a serial line.

  Image addresses:
    sau2  0x00E1C6B4  SIO_$I_XMIT_DONE

  - The transmit-active member is cleared and SIO_$I_TSTART sends the
    next character; the result is whether a transmission is active
    again.

  Status stored: none.
}

[section(wired_proc, wired_data)]
function sio_$i_xmit_done(desc: sio_$desc_ptr_t): boolean;
  options(val_param);
begin
  desc^.state := desc^.state - [0];
  sio_$i_tstart(desc);
  sio_$i_xmit_done := 0 in desc^.state;
end;
