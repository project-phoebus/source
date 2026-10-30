{ XNS_IDP_$OS_DELETE_PORT - unbind a channel from a routing port, under
  the module's lock (the OS's call).

  Image addresses:
    sau2  0x00E1876C  XNS_IDP_$OS_DELETE_PORT

  Status stored:
    xns_$delete_port's status: in either case
}

procedure xns_idp_$os_delete_port(in channel: pinteger; in port: integer;
                                  out status: status_$t);
begin
  ml_$exclusion_start(xns_idp_$lock);
  xns_$delete_port(channel, port, status);
  ml_$exclusion_stop(xns_idp_$lock);
end;
