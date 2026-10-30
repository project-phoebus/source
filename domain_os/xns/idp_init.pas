{ XNS_IDP_$INIT - initialize the XNS_IDP block at boot.

  Image addresses:
    sau2  0x00E30268  XNS_IDP_$INIT

  - The next dynamic socket is 3001, the lock initialized, every channel
    free and empty, the counters cleared.
  - The one registered address is this node's (the host
    08:00:1E:0n:nn:nn from NODE_$ME), for every port; each port's state
    gets its routing port, no MAC channel, no channels and an mtu of 0.

  Status stored: none.
}

{ TODO(pascal) 16 frame bytes of XNS_IDP_$INIT no object explains

  In the SAU2 frame the indices' slots and the two `with' temporaries
  leave 16 bytes to the stand-ins unused_10 (12 bytes, at a multiple of
  8 from A6) and unused_14 (a longword); the routine addresses no frame
  byte.  One 16-byte object would be placed at a multiple of 8, where
  these bytes do not start. }

[section(os_init_proc, os_init_data)]
procedure xns_idp_$init;
var
  ch: integer;                            { the loop's }
  p: integer;                             { the loops' }
  unused_10: array[1..3] of integer32;    { stand-in }
  unused_14: integer32;
begin
  xns_idp_$next_socket := xns_first_dynamic_port;
  ml_$exclusion_init(xns_idp_$lock);
  xns_idp_$open_channels := 0;

  for ch := 0 to xns_max_channels - 1 do
    with xns_idp_$channels[ch] do begin
      state := state - [xns_chan_state_active];
      demux := nil;
      user_socket := xns_no_socket;
      xns_socket := 0;
      flags.open_flags := 0;
      connected_port := -1;
      for p := 0 to xns_max_ports - 1 do
        port_active[p] := false;
    end;

  xns_idp_$packets_sent := 0;
  xns_idp_$packets_received := 0;
  xns_idp_$packets_dropped := 0;
  xns_idp_$registered_count := 0;
  xns_idp_$addrs[0][0] := 16#800;
  xns_idp_$addrs[0][1] := (rshft(node_$me, 16) & 16#F) ! 16#1E00;
  xns_idp_$addrs[0][2] := node_$me;
  xns_idp_$addr_port[0] := -1;

  for p := 0 to xns_max_ports - 1 do
    with xns_idp_$port_table[p] do begin
      net_addr_ptr := route_$portp[p];
      mac_socket := 16#FFFF;
      refcount := 0;
      mac_handle := 0;
    end;
end;
