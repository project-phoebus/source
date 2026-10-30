{ ROUTE_$INCOMING - a packet from a user routing port into the network.

  Image addresses:
    sau2  0x00E878A8  ROUTE_$INCOMING

  - The packet's check word, unless it is the magic value, is the sum
    of its bytes from 4, each step the sum times 17 plus the byte.
  - The data go into a network data page, the header into a header
    page, and the packet is queued on the port's socket
    (NET_IO_$PUT_IN_SOCK).  A NETBUF_$GETVA failure crashes the system.

  Status stored:
    status_$ok: the packet was queued
    status_$internet_unknown_network_port: no user port (type 2) of the
      summary
    status_$internet_network_port_not_open: the port's status is 0 or 1
    status_$route_bad_packet_format: the packet is under 28 bytes, or
      does not hold its header and data
    status_$route_checksum_error: the check word is wrong
}

{ TODO(pascal) 10 frame bytes of ROUTE_$INCOMING no object explains

  With the locals below and the port's `with' temporary, 10 bytes of the
  frame are addressed by no instruction (2 of rounding and the stand-ins
  unused_24 and unused_28).  A port pointer local would take 4 of them
  if the port's `with' were a local. }

procedure route_$incoming(in port_info: route_$short_port_t;
                          in packet_data: route_$user_pkt_t;
                          in length: pinteger;
                          out status_ret: status_$t);
var
  checksum: integer32;
  sum: integer32;
  hdr_pa: integer32;
  data_pa: integer32;
  data_va: integer32;
  hdr_va: integer32;
  index: integer;
  hdr_len: pinteger;
  i: integer;
  unused_24: integer32;                   { stand-in: the TODO above }
  unused_28: integer32;                   { stand-in }
begin
  index := route_$find_port(port_info.port_type, port_info.socket);
  if (index = -1)
     or else (port_info.port_type <> route_$port_type_routing) then begin
    status_ret.all := status_$internet_unknown_network_port;
    return;
  end;

  with route_$port[index] do
    if (active in [0, 1])
       or else (port_type <> route_$port_type_routing) then begin
      status_ret.all := status_$internet_network_port_not_open;
      return;
    end;

  if length < 28 then begin
    status_ret.all := status_$route_bad_packet_format;
    return;
  end;

  with packet_data.hdr do begin
    hdr_len := total_len;
    if hdr_len + pkt_data_len + 4 > length then begin
      status_ret.all := status_$route_bad_packet_format;
      return;
    end;

    os_$data_copy(packet_data, checksum, 4);
    if checksum <> checksum_magic then begin
      sum := checksum_magic;
      for i := 4 to length - 1 do
        sum := sum * 17 + packet_data.bytes[i];
      if sum <> checksum then begin
        status_ret.all := status_$route_checksum_error;
        return;
      end;
    end;

    if pkt_data_len = 0 then
      data_pa := 0
    else begin
      netbuf_$get_dat(data_pa);
      netbuf_$getva(data_pa, data_va, status_ret);
      if status_ret.all <> status_$ok then
        crash_system(status_ret);
      os_$data_copy(packet_data.bytes[hdr_len + 4],
                    pkt_$bytes_ptr_t(data_va)^, pkt_data_len);
      discard(netbuf_$rtnva(data_va));
    end;

    netbuf_$get_hdr(hdr_pa, hdr_va);
    os_$data_copy(packet_data.hdr, pkt_$bytes_ptr_t(hdr_va)^, hdr_len);
    net_io_$put_in_sock(2, port_info.socket, hdr_va, data_pa, hdr_len,
                        pkt_data_len);
    status_ret.all := status_$ok;
  end;
end;
