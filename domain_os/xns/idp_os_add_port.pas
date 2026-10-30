{ XNS_IDP_$OS_ADD_PORT - bind a channel to a routing port, under the
  module's lock (the OS's call).

  Image addresses:
    sau2  0x00E1872C  XNS_IDP_$OS_ADD_PORT

  Status stored:
    xns_$add_port's status: in either case
}

procedure xns_idp_$os_add_port(in channel: pinteger; in port: integer;
                               out status: status_$t);
begin
  ml_$exclusion_start(xns_idp_$lock);
  xns_$add_port(channel, port, status);
  ml_$exclusion_stop(xns_idp_$lock);
end;
