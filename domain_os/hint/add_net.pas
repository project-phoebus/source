{ HINT_$ADD_NET - record the network port in the hint file's header.

  Image addresses:
    sau2  0x00E49C76  HINT_$ADD_NET

  - If the hint file is published, the network and port 0's type and
    socket go into the file's header under HINT_$EXCLUSION_LOCK.

  Status stored: none.
}

procedure hint_$add_net(port: integer32);
begin
  if hint_$hintfile_ptr = nil then return;

  ml_$exclusion_start(hint_$exclusion_lock);
  with hint_$hintfile_ptr^ do begin
    net_port := port;
    port_type := route_$portp[0]^.port_type;
    socket := route_$portp[0]^.socket;
  end;
  ml_$exclusion_stop(hint_$exclusion_lock);
end;
