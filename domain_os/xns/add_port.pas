{ xns_$add_port - bind a channel to a routing port.

  Image addresses:
    sau2  0x00E17BF8  xns_$add_port

  - The first channel on a port opens MAC_OS on it for the XNS frame
    type, with XNS_IDP_$OS_DEMUX as the receive routine, and keeps
    MAC_OS's channel and mtu in the port's state.
  - The port is then marked active for the channel and its count of
    channels raised, unless it was active already.

  Status stored:
    status_$ok: the channel was bound
    status_$internet_network_port_not_open (16#2B0001): the port's
      routing state is 0 or 1
    mac_os_$open's status: the MAC_OS open failed
}

{ TODO(pascal) 4 frame bytes in three XNS_IDP helper functions no
  object explains

  With every local's slot, the result variable's word and the `with''s
  temporary counted, the SAU2 frames of
  xns_$find_socket (the slot, i, the result, the temporary: 12) and
  xns_$is_broadcast_addr (the slot, p, i, the result: 10, rounded 12)
  have 4 more bytes, held by stand-ins; XNS_ERROR's two module-local
  functions have the same 4 (see the TODO(pascal) in
  xns/is_local_addr.pas).  The two helper procedures have none:
  xns_$add_port and xns_$delete_port fit exactly once the `with'
  temporary is counted, and xns_$get_checksum, a function
  without a `with', fits exactly too.  A rule for `internal' functions'
  frames (a longword for the result?) would explain the four;
  xns_$get_checksum's frame would hold it as well (its result's word
  lies above a temporary rounded to 4). }

procedure xns_$add_port(channel: pinteger; port: integer;
                        out status: status_$t); internal;
var
  params: mac_os_$open_params_t;
begin
  status.all := status_$ok;

  with xns_idp_$port_table[port] do begin
    if refcount = 0 then begin
      if route_$port[port].active in [0, 1] then begin
        status.all := status_$internet_network_port_not_open;
        return;
      end;
      params.callback := mac_os_$callback_t(addr(xns_idp_$os_demux));
      params.num_pkt_types := 1;
      params.pkt_types[0].range_low := xns_mac_frame_type;
      params.pkt_types[0].range_high := xns_mac_frame_type;
      mac_os_$open(port, params, status);
      if status.all <> status_$ok then
        return;
      mac_socket := params.channel;
      mac_handle := params.mtu;
    end;
    if status.all = status_$ok then
      if not xns_idp_$channels[channel].port_active[port] then begin
        xns_idp_$channels[channel].port_active[port] := true;
        refcount := refcount + 1;
      end;
  end;
end;
