{ XNS_IDP_$OS_OPEN - open an IDP channel (the OS's call).

  Image addresses:
    sau2  0x00E17F02  XNS_IDP_$OS_OPEN

  - Under the module's lock the first free channel is taken.  With
    bind_local it is bound to every routing port (network -1) or to the
    given network's.
  - With connect it is bound to the next hop's port, with the
    destination's link address (MAC_OS_$ARP) and the two addresses.
  - A zero socket gets the next free one from 3001 on.  The channel is
    marked open with the caller's address space; its index goes back in
    the record.  On any failure the channel is freed again.

  Status stored:
    status_$ok: the channel was opened
    status_$xns_idp_socket_table_full (16#3B000D): 16 channels are open
    status_$xns_socket_in_use (16#3B000E): the socket is taken
    status_$xns_channel_table_full (16#3B0001): no free channel
    status_$xns_listen_network_not_connected (16#3B000B): no port has
      the network
    status_$xns_source_must_be_this_node (16#3B001B): another node's
      source
    status_$xns_network_unreachable (16#3B0013): no next hop port
    the callees' statuses: a bind, RIP_$FIND_NEXTHOP or MAC_OS_$ARP
      failed
}

{ TODO(pascal) 14 frame bytes of XNS_IDP_$OS_OPEN no object explains

  With every local in the order declared (each register-held one
  keeping a slot) and the three `with' temporaries below them, the SAU2
  frame puts nexthop, port_num and is_bcast where the image addresses
  them only with 6 bytes between i and is_bcast and 8 below is_bcast
  (the stand-ins unused_1e, unused_28).  Folded locals (a second port
  variable, the open flag byte, a channel pointer) would fill some of
  them. }

procedure xns_idp_$os_open(in out opt: xns_$os_open_opt_t;
                           out status: status_$t);
label
  10;
var
  channel: pinteger;
  bound: boolean;
  port: integer;
  nexthop: rip_$nexthop_t;
  p: integer;
  use_local: boolean;
  port_num: integer;
  i: integer;                             { the copy loop's }
  unused_1e: array[1..3] of integer;      { stand-in }
  is_bcast: boolean;
  unused_28: array[1..2] of integer32;    { stand-in }
begin
  status.all := status_$ok;
  if xns_idp_$open_channels >= xns_max_channels then begin
    status.all := status_$xns_idp_socket_table_full;
    return;
  end;

  if opt.socket <> 0 then
    if xns_$find_socket(opt.socket) then begin
      status.all := status_$xns_socket_in_use;
      goto 10;
    end;

  ml_$exclusion_start(xns_idp_$lock);
  channel := 0;
  while xns_chan_state_active in xns_idp_$channels[channel].state do begin
    if channel >= xns_max_channels then begin
      status.all := status_$xns_channel_table_full;
      goto 10;
    end;
    channel := channel + 1;
  end;

  if xns_open_flag_bind_local in opt.flags then begin
    if opt.network = -1 then begin
      bound := false;
      for p := 0 to xns_max_ports - 1 do begin
        xns_$add_port(channel, p, status);
        if status.all = status_$ok then
          bound := true;
      end;
      if bound then
        if (status.all = status_$internet_network_port_not_open)
           or else (status.all = status_$mac_port_op_not_implemented) then
          status.all := status_$ok;
    end
    else begin
      mac_$net_to_port_num(opt.network, port_num);
      port := port_num;
      if port = -1 then begin
        status.all := status_$xns_listen_network_not_connected;
        goto 10;
      end;
      xns_$add_port(channel, port, status);
    end;
    if status.all <> status_$ok then
      goto 10;
  end;

  use_local := false;
  if xns_open_flag_connect in opt.flags then begin
    if (opt.src.network = 0) and then (opt.src.socket = 0)
       and then (opt.src.host[0] = 0) and then (opt.src.host[1] = 0)
       and then (opt.src.host[2] = 0) then
      use_local := true
    else if not xns_$is_broadcast_addr(opt.src) then begin
      status.all := status_$xns_source_must_be_this_node;
      goto 10;
    end;

    discard(rip_$find_nexthop(opt.dest, true, port_num, nexthop, status));
    port := port_num;
    if status.all <> status_$ok then
      goto 10;
    if port = -1 then begin
      status.all := status_$xns_network_unreachable;
      goto 10;
    end;
    mac_os_$arp(nexthop, port, xns_idp_$channels[channel].mac_info,
                is_bcast, status);
    if status.all <> status_$ok then
      goto 10;
    xns_$add_port(channel, port, status);
    if status.all <> status_$ok then
      goto 10;

    with xns_idp_$channels[channel] do begin
      dest := opt.dest;
      connected_port := port;
      if use_local then begin
        src.network := xns_idp_$port_table[port].net_addr_ptr^.network;
        for i := 0 to 2 do
          src.host[i] := xns_idp_$addrs[0][i];
        src.socket := xns_socket;
      end
      else
        src := opt.src;
    end;
  end;

  if opt.socket = 0 then begin
    opt.socket := xns_idp_$next_socket;
    repeat
      xns_idp_$next_socket := xns_idp_$next_socket + 1;
      if xns_idp_$next_socket > 16#FFFE then
        xns_idp_$next_socket := xns_first_dynamic_port;
    until not xns_$find_socket(xns_idp_$next_socket);
  end;

  xns_idp_$open_channels := xns_idp_$open_channels + 1;
  with xns_idp_$channels[channel] do begin
    state := state + [xns_chan_state_active];
    xns_socket := opt.socket;
    user_socket := xns_no_socket;
    demux := opt.demux;
    flags.open_flags := opt.flags_channel;
    flags.owner := proc1_$as_id;
  end;

10:
  if status.all = status_$ok then
    opt.flags_channel := channel
  else
    with xns_idp_$channels[channel] do begin
      state := state - [xns_chan_state_active];
      demux := nil;
    end;
  ml_$exclusion_stop(xns_idp_$lock);
end;
