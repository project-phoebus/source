{ RIP_$SEND - send a RIP packet to one port or every port.

  Image addresses:
    sau2  0x00E871B6  RIP_$SEND
    sau2  0x00E87000  rip_$send_to_port_internet (nested)
    sau2  0x00E870DC  rip_$send_to_port (nested)

  - Over the standard routing (flags) the packet goes out as an IDP
    packet on the standard IDP channel (rip_$send_to_port); over the
    Domain internet through NET_IO_$SEND (rip_$send_to_port_internet).
  - For port -1 every port routing for the routing gets the packet, to
    the broadcast host on socket 1 of its own network.
  - A port of type 2 has its eventcount advanced.

  Status stored: none.
}

{ TODO(pascal) 10 frame bytes of RIP_$SEND's family hold nothing

  Below nexthop_port, the slots of i and k take 4 of the frame's last
  10 bytes; nothing addresses the other 6.  rip_$send_to_port's frame
  has the link's slot and port's, 8 of its 12 bytes; its sibling's has
  exactly these.  Stand-ins unused_7c and unused_c hold the places. }

procedure rip_$send(var addr_info: route_$xns_addr_t;
                    port_index: integer;
                    in route_data: univ rip_$packet_t;
                    route_len: integer;
                    flags: boolean);
var
  send_rec: xns_$os_send_rec_t;
  hdr_data: rip_$data_ptr_t;
  route_data_p: rip_$data_ptr_t;
  status: status_$t;
  hdr: xns_$idp_header_ptr_t;
  send_info: net_io_$send_info_t;
  hdr_pa: integer32;
  hdr_cell: record
    case integer of
      1: (va: integer32);
      2: (ptr: pkt_$hdr_ptr_t);
  end;
  pkt_len: integer;
  len_sent: integer;
  timeout: pinteger;
  retry_hint: integer;
  hdr_len: integer;
  pkt_id: pinteger;
  nexthop_port: integer;
  i: integer;
  k: integer;
  unused_7c: array[1..3] of integer;      { stand-in, see the TODO }

  procedure rip_$send_to_port_internet(port_index: integer);
  var
    port: route_$port_ptr_t;
  begin
    network_$gethdr(0, hdr_cell.ptr, hdr_pa);
    port := addr(route_$port[port_index]);
    pkt_$bld_internet_hdr(port^.network, 0, rip_socket, port^.network,
                          node_$me, rip_socket, rip_$bcast_control, pkt_id,
                          route_data, route_len, 0, nexthop_port,
                          hdr_cell.ptr^, hdr_len, retry_hint, timeout,
                          status);

    if status.all = status_$ok then
      net_io_$send(port_index, hdr_cell.ptr, hdr_pa, hdr_len, 0, 0, 0,
                   rip_$send_flags, send_info, status);
    network_$rtnhdr(hdr_cell.ptr);
    if port^.port_type = route_$port_type_routing then
      ec_$advance(port^.part_34.port_ec);
  end;

  procedure rip_$send_to_port(port_index: integer);
  var
    port: route_$port_ptr_t;
    unused_c: integer32;                  { stand-in, see the TODO }
  begin
    netbuf_$get_hdr(hdr_pa, hdr_cell.va);
    port := addr(route_$port[port_index]);

    hdr := xns_$idp_header_ptr_t(hdr_cell.va);
    hdr^.checksum := 16#FFFF;
    hdr^.length := pkt_len;
    hdr^.transport_ctl := 0;
    hdr^.packet_type := 1;
    hdr^.dest := addr_info;
    hdr^.src := port^.xns_addr[0];
    hdr^.src.socket := 1;

    hdr_data := rip_$data_ptr_t(integer32(hdr) + xns_idp_header_size);
    os_$data_copy(route_data_p^, hdr_data^, route_len);

    send_rec.hdr_desc.address := integer32(hdr);
    xns_idp_$os_send(rip_$std_idp_channel, send_rec, len_sent, status);
    netbuf_$rtn_hdr(hdr_cell.va);
    if port^.port_type = route_$port_type_routing then
      ec_$advance(port^.part_34.port_ec);
  end;

begin
  if flags then begin
    pkt_len := xns_idp_header_size + route_len;
    route_data_p := addr(route_data);
    send_rec.hdr_desc.length := pkt_len;
    send_rec.hdr_desc.next := nil;
    send_rec.hdr_prebuilt := true;
    send_rec.data.length := 0;
    send_rec.data.pages[1] := 0;
  end
  else
    pkt_id := pkt_$next_id;

  if port_index = -1 then begin
    for k := 0 to 2 do
      addr_info.host[k] := 16#FFFF;
    addr_info.socket := 1;
    for i := 0 to 7 do begin
      addr_info.network := route_$port[i].network;
      if (not flags) and then (route_$port[i].active in [3, 5]) then
        rip_$send_to_port_internet(i)
      else if flags and then (route_$port[i].active in [4, 5]) then
        rip_$send_to_port(i);
    end;
  end
  else if flags then
    rip_$send_to_port(port_index)
  else
    rip_$send_to_port_internet(port_index);
end;
