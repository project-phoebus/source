{ XNS_IDP_$PROC2_CLEANUP - close the IDP channels of an ending address
  space.

  Image addresses:
    sau2  0x00E18F0E  XNS_IDP_$PROC2_CLEANUP

  - Under the module's lock every open channel the address space owns
    has its user socket closed, is unbound from its ports, freed and
    counted as closed.

  Status stored: none.
}

{ TODO(pascal) 8 frame bytes of XNS_IDP_$PROC2_CLEANUP no object
  explains

  In the SAU2 frame del_status, the two indices' slots and the `with''s
  temporary leave 8 bytes to the stand-in unused_10. }

procedure xns_idp_$proc2_cleanup(as_id: integer);
var
  del_status: status_$t;
  ch: integer;
  p: integer;
  unused_10: array[1..2] of integer32;    { stand-in }
begin
  ml_$exclusion_start(xns_idp_$lock);

  for ch := 0 to xns_max_channels - 1 do
    with xns_idp_$channels[ch] do
      if (xns_chan_state_active in state) and then (flags.owner = as_id)
      then begin
        if user_socket <> xns_no_socket then
          sock_$close(user_socket);
        for p := 0 to xns_max_ports - 1 do
          if port_active[p] then
            xns_$delete_port(ch, p, del_status);
        state := state - [xns_chan_state_active];
        flags.open_flags := 0;
        user_socket := xns_no_socket;
        xns_socket := 0;
        xns_idp_$open_channels := xns_idp_$open_channels - 1;
      end;

  ml_$exclusion_stop(xns_idp_$lock);
end;
