{ net_io_$put_in_sock_common - deliver a packet to a socket of this node.

  Image addresses:
    sau2  0x00E0E238  net_io_$put_in_sock_common (module-local)

  - The port is found when none is given (none crashes the system) and
    the destination socket taken from the header (ROUTE_$SOCK for
    another node); the packet is logged when ring logging is on.
  - An all-ones source, and one broadcast form, are dropped.  The packet
    is queued (SOCK_$PUT_INT, else SOCK_$PUT), socket 2's refusals going
    to socket 6; the result is whether a socket took it.
  - The packet is stamped and counted before a socket is offered it.

  Status stored: none.
}

{ TODO(pascal) put_in_sock_common's frame has bytes no local accounts for

  The SAU2 frame is 104 bytes.  The image places rec (64 bytes), now
  (6), flags7 (2) and the result variable; with the reserved longword at
  the top and slots for the register-held locals (p, hdr: 4 each; dsock,
  i: 2 each; to_router, queued: 1 each) the declared objects take about
  92 bytes.  The open bytes are 4 above rec (one longword local), 6, 2
  and 4 between the placed objects and 10 below the result variable;
  which locals the original declared, and in what order, the image does
  not show.  `dpc --dump-locals' gives its own order. }

function net_io_$put_in_sock_common(port: route_$port_ptr_t;
                                    port_type: integer;
                                    socket: pinteger;
                                    int_level: boolean;
                                    var hdr_va: integer32;
                                    in data_pa: pkt_$data_pages_t;
                                    hdr_len: pinteger;
                                    data_len: pinteger;
                                    out ec_ret: ec_$eventcount_ptr_t):
  boolean;
  internal;
label
  drop;
var
  p: route_$port_ptr_t;
  rec: sock_$pkt_info_t;
  dsock: pinteger;
  to_router: boolean;
  i: integer;
  now: time_$clock_t;
  flags7: pkt_$hdr_bits_t;
  hdr: pkt_$hdr_ptr_t;
  queued: boolean;
begin
  if ring_$logging_now then
    discard(ringlog_$logit(true, pkt_$hdr_ptr_t(hdr_va)^));

  to_router := false;
  if port = nil then begin
    p := route_$find_portp(port_type, socket);
    if p = nil then
      crash_system(status_$internet_unknown_network_port);
  end
  else
    p := port;

  hdr := pkt_$hdr_ptr_t(hdr_va);
  if hdr^.routing_type = pkt_$routing_local then begin
    hdr^.route_count := hdr^.route_count + 1;
    dsock := hdr^.route[hdr^.route_count];
  end
  else begin
    if (hdr^.src.node & net_io_$all_f_addr) = net_io_$all_f_addr then
      goto drop;
    if hdr^.src.net = 0 then
      hdr^.src.net := p^.network;
    if (hdr^.dest.node = node_$me)
       or else (pkt_$hdr_broadcast in hdr^.flag_bits.info_bits) then
      dsock := hdr^.dest.sock
    else begin
      dsock := route_$sock;
      to_router := true;
    end;
  end;

  if (hdr^.dest_node = 2) and then (dsock = 4)
     and then (pkt_$hdr_broadcast in hdr^.flag_bits.info_bits) then begin
    flags7 := hdr^.flag_bits.flags_07;
    if 3 in flags7 then
      goto drop;
  end;

  time_$abs_clock(now);
  if netlog_$ok_to_log_server then begin
    hdr^.dest_node := now.high;
    hdr^.flag_bits.arrival_lo := now.low;
  end
  else
    hdr^.dest_node := time_$clockh;
  p^.stat_long_54 := p^.stat_long_54 + 1;

  net_io_$put_in_sock_common := true;
  rec.hdr := integer32(hdr);
  rec.hdr_len := hdr_len;
  rec.data_len := data_len;
  rec.n_hops := 0;
  for i := 1 to 4 do
    rec.data_pages[i] := data_pa[i];
  rec.flags := [];
  rec.src_addr := now.high;
  rec.src_port := now.low;

  if int_level then
    queued := sock_$put_int(dsock, rec, not to_router, port_type, socket,
                            ec_ret)
  else
    queued := sock_$put(dsock, rec, not to_router, port_type, socket);
  if queued then
    return;

  if dsock = 2 then begin
    ring_$file_overflow := ring_$file_overflow + 1;
    if int_level then
      queued := sock_$put_int(6, rec, not to_router, port_type, socket,
                              ec_ret)
    else
      queued := sock_$put(6, rec, not to_router, port_type, socket);
    if queued then
      return;
    ring_$overflow_overflow := ring_$overflow_overflow + 1;
  end
  else if (dsock = route_$sock) and then (route_$sock <> -1) then
    route_$q_oflo := route_$q_oflo + 1
  else
    ring_$delivery_failed := ring_$delivery_failed + 1;

drop:
  netbuf_$rtn_hdr(hdr_va);
  if data_pa[1] <> 0 then
    pkt_$dump_data(data_pa, data_len);
  net_io_$put_in_sock_common := false;
end;
