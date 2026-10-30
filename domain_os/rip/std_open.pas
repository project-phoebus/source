{ RIP_$STD_OPEN - open the standard routing's IDP channel.

  Image addresses:
    sau2  0x00E15AAE  RIP_$STD_OPEN

  - An IDP channel is opened on XNS's routing information socket, bound
    to the local network (route_$port[0]'s) with RIP_$STD_DEMUX as its
    demux routine; on success its index goes into RIP_$STD_IDP_CHANNEL.
  - The frame: opt, 36 bytes, below 4 open bytes, then status (as
    app/std_open.pas's frame and its TODO).

  Status stored: none.
}

procedure rip_$std_open;
var
  opt: xns_$os_open_opt_t;
  status: status_$t;
begin
  opt.socket := rip_std_socket;
  opt.flags_channel := rip_open_flag_bind_local;
  opt.network := route_$port[0].network;
  opt.demux := addr(rip_$std_demux);

  xns_idp_$os_open(opt, status);

  if status.all = status_$ok then
    rip_$std_idp_channel := opt.flags_channel;
end;
