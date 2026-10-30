{ XNS_IDP_$OPEN - open an IDP channel (the user's call).

  Image addresses:
    sau2  0x00E187AC  XNS_IDP_$OPEN

  - Unless send-only, a user socket is allocated with the record's depth
    and marked not open; XNS_IDP_$OS_OPEN opens the channel (a failure
    gives the socket back).
  - The process's IDP cleanup is set, the channel gets the user socket,
    and the caller the channel's index and an EC2 eventcount for it.
  - A send-only open registers an eventcount for socket xns_no_socket.

  Status stored:
    status_$ok: the channel was opened
    status_$xns_version_mismatch: a record version other than 1
    status_$xns_reserved_socket: socket 16#FFFF, 0x499, 3 or 1
    status_$xns_socket_in_use: an open channel has the socket
    status_$xns_incompatible_flags: listen with send-only
    status_$xns_connect_bind_conflict: listen with connect
    status_$xns_incompatible_flags2: connect with send-only
    status_$xns_connect_to_broadcast: connect with a broadcast host at
      either end
    status_$xns_no_os_sockets: no user socket
    status_$xns_no_buffer_size: no depth given
    xns_idp_$os_open's or ec2_$register_ec1's status: those failed
}

procedure xns_idp_$open(in out opt: xns_$idp_open_opt_t;
                        out status: status_$t);
var
  sock_ptr: sock_$sock_ptr_t;
  os_opt: xns_$os_open_opt_t;
  os_status: status_$t;
  user_socket: pinteger;                  { held, with its slot }
begin
  status.all := status_$ok;
  if opt.version <> 1 then begin
    status.all := status_$xns_version_mismatch;
    return;
  end;

  if (opt.socket = -1) or else (opt.socket = xns_socket_router)
     or else (opt.socket = xns_socket_error)
     or else (opt.socket = xns_socket_rip) then begin
    status.all := status_$xns_reserved_socket;
    return;
  end;
  if opt.socket <> 0 then
    if xns_$find_socket(opt.socket) then begin
      status.all := status_$xns_socket_in_use;
      return;
    end;

  if xns_open_flag_bind_local in opt.flags then begin
    if xns_open_flag_no_alloc in opt.flags then begin
      status.all := status_$xns_incompatible_flags;
      return;
    end;
    if xns_open_flag_connect in opt.flags then begin
      status.all := status_$xns_connect_bind_conflict;
      return;
    end;
  end;
  if xns_open_flag_connect in opt.flags then begin
    if xns_open_flag_no_alloc in opt.flags then begin
      status.all := status_$xns_incompatible_flags2;
      return;
    end;
    if ((opt.dest.host[2] = 16#FFFF) and then (opt.dest.host[0] = 16#FFFF)
        and then (opt.dest.host[1] = 16#FFFF))
       or else ((opt.src.host[2] = 16#FFFF)
                and then (opt.src.host[0] = 16#FFFF)
                and then (opt.src.host[1] = 16#FFFF)) then begin
      status.all := status_$xns_connect_to_broadcast;
      return;
    end;
  end;

  if xns_open_flag_no_alloc in opt.flags then
    user_socket := xns_no_socket
  else if opt.buffer_size <> 0 then begin
    if not sock_$allocate_user(user_socket, opt.buffer_size,
                               opt.buffer_size, opt.buffer_size, 16#400)
    then begin
      status.all := status_$xns_no_os_sockets;
      return;
    end;
    sock_ptr := sock_$socket_ptr[user_socket];
    sock_ptr^.flags.open := false;
  end
  else begin
    status.all := status_$xns_no_buffer_size;
    return;
  end;

  os_opt.socket := opt.socket;
  os_opt.demux := addr(xns_idp_$demux);
  os_opt.flags := opt.flags;
  if xns_open_flag_bind_local in opt.flags then
    os_opt.network := opt.network;
  if xns_open_flag_connect in opt.flags then
    os_opt.addrs := opt.addrs;

  xns_idp_$os_open(os_opt, os_status);
  status := os_status;
  if os_status.all <> status_$ok then begin
    if user_socket <> xns_no_socket then
      sock_$close(user_socket);
    return;
  end;

  proc2_$set_cleanup(16#0E);
  ml_$exclusion_start(xns_idp_$lock);
  xns_idp_$channels[os_opt.flags_channel].user_socket := user_socket;
  ml_$exclusion_stop(xns_idp_$lock);

  opt.channel_ret := os_opt.flags_channel;
  sock_ptr := sock_$socket_ptr[user_socket];
  opt.ec := ec2_$register_ec1(addr(sock_ptr^.ec), status);
end;
