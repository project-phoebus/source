{ SIO_$I_DCD_CHANGE - the data-carrier-detect line of a serial line
  changed.

  Image addresses:
    sau2  0x00E1C73E  SIO_$I_DCD_CHANGE

  - A carrier lost on a line that hangs up on DCD loss calls its DCD
    handler; a carrier present restarts the transmission.
  - A line reporting DCD changes gets the condition pending and its
    data_rcv handler called with the character 0; the eventcount is
    advanced without dispatching.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure sio_$i_dcd_change(desc: sio_$desc_ptr_t; state: boolean);
  options(val_param);
begin
  if not state and then (2 in desc^.params.flags2) then begin
    if desc^.handlers.dcd_handler <> nil then
      sio_$owner_proc_t(desc^.handlers.dcd_handler)^(desc^.owner);
  end
  else if state then
    sio_$i_tstart(desc);

  if 3 in desc^.params.break_mask then begin
    desc^.pending_int := desc^.pending_int + [3];
    if desc^.data_rcv <> nil then
      sio_$rcv_proc_t(desc^.data_rcv)^(desc^.owner, chr(0));
  end;

  ec_$advance_without_dispatch(desc^.ec);
end;
