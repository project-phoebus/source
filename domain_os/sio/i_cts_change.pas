{ SIO_$I_CTS_CHANGE - the clear-to-send line of a serial line changed.

  Image addresses:
    sau2  0x00E1C6DA  SIO_$I_CTS_CHANGE

  - CTS asserted clears the CTS-blocked member and restarts the
    transmission; CTS dropped blocks a line with CTS flow control.
  - A line reporting CTS changes gets the condition pending and its
    data_rcv handler called with the character 0; the eventcount is
    advanced without dispatching.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure sio_$i_cts_change(desc: sio_$desc_ptr_t; state: boolean);
  options(val_param);
begin
  if state then begin
    desc^.state := desc^.state - [1];
    sio_$i_tstart(desc);
  end
  else if 1 in desc^.params.flags2 then
    desc^.state := desc^.state + [1];

  if 4 in desc^.params.break_mask then begin
    desc^.pending_int := desc^.pending_int + [4];
    if desc^.data_rcv <> nil then
      sio_$rcv_proc_t(desc^.data_rcv)^(desc^.owner, chr(0));
  end;

  ec_$advance_without_dispatch(desc^.ec);
end;
