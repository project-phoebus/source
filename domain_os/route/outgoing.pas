{ ROUTE_$OUTGOING - a packet from the network out to a user routing port.

  Image addresses:
    sau2  0x00E87A4E  ROUTE_$OUTGOING

  - A packet is taken from the port's socket; RIP's next hop's node and
    the packet's broadcast bit go back to the user, then the header and
    as much of the data as fits behind the check word in 0x800 bytes.
  - The check word is the magic value, or with ROUTE_$USER_CHECKSUM set
    the sum of the bytes from 4 (each step the sum times 17 plus the
    byte).
  - RIP_$FIND_NEXTHOP is asked about a destination whose 24-bit node is
    merged unmasked into the 20-bit host field.

  Status stored:
    status_$ok: a packet was given out
    status_$internet_unknown_network_port: no user port (type 2) of the
      summary
    status_$internet_network_port_not_open: the port is not open
    status_$network_buffer_queue_is_empty: no packet
    rip_$find_nexthop's status: no next hop (the buffers returned)
}

{ TODO(pascal) 26 frame bytes of ROUTE_$OUTGOING no object explains

  With the locals below (the records 8-aligned) and the port's `with'
  temporary, 26 bytes are addressed by no instruction: the stand-ins
  unused_78, unused_7c and unused_88 .. unused_94.  A port pointer and
  the socket's and the type's words would take some of them.  dpc does
  not 8-align frame objects. }

procedure route_$outgoing(in port_info: route_$short_port_t;
                          out nexthop_ret: route_$nexthop_ret_t;
                          out packet_buf: route_$user_pkt_t;
                          out length_ret: integer;
                          out status_ret: status_$t);
var
  dest_addr: rip_$dest_addr_t;
  rcv: sock_$pkt_info_t;
  next_hop: rip_$nexthop_t;
  pkt: pkt_$hdr_ptr_t;
  index: integer;
  hdr_len: pinteger;
  data_len: pinteger;
  copy_len: integer;
  pkt_len: integer;
  i: integer;
  checksum: integer32;
  unused_78: integer32;                   { stand-in: the TODO above }
  unused_7c: integer32;                   { stand-in }
  hdr_cell: record
    case integer of
      1: (va: integer32);
      2: (ptr: pkt_$hdr_ptr_t);
  end;
  hop_port: integer;
  unused_88: integer32;                   { stand-in }
  unused_8c: integer32;                   { stand-in }
  unused_90: integer32;                   { stand-in }
  unused_94: integer32;                   { stand-in }
begin
  index := route_$find_port(port_info.port_type, port_info.socket);
  if index = -1 then begin
    status_ret.all := status_$internet_unknown_network_port;
    return;
  end;
  with route_$port[index] do
    if (active in [0, 1])
       or else (port_type <> route_$port_type_routing) then begin
      status_ret.all := status_$internet_network_port_not_open;
      return;
    end;

  if not sock_$get(port_info.socket, rcv) then begin
    status_ret.all := status_$network_buffer_queue_is_empty;
    return;
  end;

  pkt := pkt_$hdr_ptr_t(rcv.hdr);
  hdr_len := pkt^.total_len;
  data_len := pkt^.pkt_data_len;
  with pkt^ do begin
    dest_addr.network := dest.net;
    dest_addr.host_node := dest.node;
  end;

  discard(rip_$find_nexthop(dest_addr, false, hop_port, next_hop,
                            status_ret));
  if status_ret.all <> status_$ok then begin
    hdr_cell.ptr := pkt;
    netbuf_$rtn_hdr(hdr_cell.va);
    pkt_$dump_data(rcv.data_pages, data_len);
    return;
  end;

  nexthop_ret.node := next_hop.host_lo & 16#FFFFF;
  nexthop_ret.broadcast := pkt_$hdr_broadcast in pkt^.flag_bits.info_bits;
  os_$data_copy(pkt^, packet_buf.hdr, hdr_len);
  hdr_cell.ptr := pkt;
  netbuf_$rtn_hdr(hdr_cell.va);

  if rcv.data_pages[1] = 0 then
    data_len := 0;
  if data_len <> 0 then begin
    copy_len := min(route_$max_packet_data - hdr_len, data_len);
    pkt_$dat_copy(rcv.data_pages, copy_len,
                  integer32(addr(packet_buf.bytes[hdr_len + 4])));
    pkt_$dump_data(rcv.data_pages, data_len);
  end else
    copy_len := 0;

  pkt_len := hdr_len + copy_len + 4;
  length_ret := pkt_len;

  checksum := checksum_magic;
  if route_$user_checksum then
    for i := 4 to pkt_len - 1 do
      checksum := checksum * 17 + packet_buf.bytes[i];
  os_$data_copy(checksum, packet_buf, 4);
end;
