{ SIO_$I_INHIBIT_RCV - stop or resume a serial line's receiver.

  Image addresses:
    sau2  0x00E1C94A  SIO_$I_INHIBIT_RCV

  - On a line with software flow control the receiver-enabled member is
    cleared or set and the driver's set_params entry applies it (its
    status not read).
  - With update_xmit the XON/XOFF handshake members are set up (XOFF to
    send when inhibiting) and SIO_$I_TSTART sends what is due.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure sio_$i_inhibit_rcv(desc: sio_$desc_ptr_t; inhibit: boolean;
                             update_xmit: boolean);
  options(val_param);
var
  status: status_$t;
begin
  { the receiver, by the line's soft flow }
  if 0 in desc^.params.flags2 then begin
    if inhibit then
      desc^.params.flags1 := desc^.params.flags1 - [0]
    else
      desc^.params.flags1 := desc^.params.flags1 + [0];
    sio_$set_params_t(desc^.driver.set_params)^(desc^.context,
                                                desc^.params, [5], status);
  end;

  { the transmitter's handshake }
  if update_xmit then begin
    if inhibit then begin
      desc^.state := desc^.state - [5];
      if not (7 in desc^.state) then
        desc^.state := desc^.state + [6];
    end
    else begin
      if 7 in desc^.state then
        desc^.state := desc^.state + [5];
      desc^.state := desc^.state - [6];
    end;
    sio_$i_tstart(desc);
  end;
end;
