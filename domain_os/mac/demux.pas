{ MAC_$DEMUX - the receive callback of MAC channels: queue a packet on
  the channel's socket.

  Image addresses:
    sau2  0x00E0BC4E  MAC_$DEMUX

  - The socket layer's packet record is built from MAC_OS's (the flags,
    the link address's words as hops, the arrival time, the frame type,
    the header and the data) and queued with SOCK_$PUT.
  - A MAC_OS fragment (mac/README.md).

  Status stored:
    status_$ok: the packet was queued
    status_$mac_XXX_unknown (16#3A000F): the channel has no socket
    status_$mac_failed_to_put_packet_into_socket: SOCK_$PUT failed
}

{ TODO(pascal) the word copy's guard has no test after the bound's
  subtraction

  The SAU2 image computes the bound n - 1 and branches on the
  subtraction's flags, then forms the two pointers from the records'
  bases.  The pointers say the loop starts at index 0 of 0-based arrays
  (the pointer starts at the base plus from times
  the size, the displacement holds the field's offset less lo times the
  size), so the source is `for i := 0 to n - 1'.  The known guard of a
  loop from 0 is a test of the count copied to itself, for a bound that
  is a variable; here the bound is the expression n - 1 and the
  subtraction's flags serve, the known form of a loop from 1.
  MAC_$RECEIVE's copy back and MAC_$OPEN's loops have the same shape.
  Not a known form. }

procedure mac_$demux(in pkt: mac_os_$rcv_pkt_t; in port_num: integer;
                     in demux_flag: boolean; out status: status_$t);
var
  desc: sock_$pkt_info_t;
  chan: mac_os_$channel_ptr_t;
  route_port: route_$port_ptr_t;
  i: integer;
begin
  status.all := status_$ok;
  desc.flags := [sock_pkt_flag_xns];
  if pkt.is_local then
    desc.flags := desc.flags + [sock_pkt_flag_local];
  if demux_flag then
    desc.flags := desc.flags + [sock_pkt_flag_demux_bool];

  desc.n_hops := pkt.link_addr.n_words;
  for i := 0 to pkt.link_addr.n_words - 1 do
    desc.hops[i] := pkt.link_addr.addr[i];

  desc.src_addr := pkt.time.high;
  desc.src_port := pkt.time.low;
  desc.dst_addr := pkt.frame_type;
  desc.hdr := pkt.body;
  desc.hdr_len := pkt.body_len;
  desc.data_len := pkt.data_len;
  desc.data_pages := pkt.data_pa;

  chan := pkt.channel;
  route_port := route_$portp[port_num];
  if chan^.socket = mac_os_no_socket then
    status.all := status_$mac_XXX_unknown
  else if not sock_$put(chan^.socket, desc, false, route_port^.port_type,
                        route_port^.socket) then
    status.all := status_$mac_failed_to_put_packet_into_socket;
end;
