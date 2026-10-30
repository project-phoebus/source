{ xns_$delete_port - unbind a channel from a routing port.

  Image addresses:
    sau2  0x00E17CB2  xns_$delete_port

  - The port is marked inactive for the channel and its count of
    channels lowered; at 0 MAC_OS's channel on the port is closed and
    forgotten (16#FFFF).

  Status stored:
    status_$ok: the channel was unbound
    mac_os_$close's status: the MAC_OS close failed
}

procedure xns_$delete_port(channel: pinteger; port: integer;
                           out status: status_$t); internal;
begin
  status.all := status_$ok;
  xns_idp_$channels[channel].port_active[port] := false;

  with xns_idp_$port_table[port] do begin
    refcount := refcount - 1;
    if refcount = 0 then begin
      mac_os_$close(mac_socket, status);
      mac_socket := 16#FFFF;
    end;
  end;
end;
