{ APP_$DEMUX - queue a packet of the application channel on its socket.

  Image addresses:
    sau2  0x00E00A90  APP_$DEMUX

  - The application IDP channel's demux routine, called through the
    channel's demux field (APP_$STD_OPEN stores it).
  - The packet goes on the socket its header names (SOCK_$PUT); a file
    socket packet that does not fit is counted and tried on the overflow
    socket.  A packet nobody took, or a broadcast to drop, has its
    buffers returned.

  Status stored:
    status_$ok: always
}

{ TODO(pascal) 8 frame bytes that nothing addresses

  The SAU2 image's frame has 8 bytes below rec and app_hdr's slot that
  are never addressed.  The routine keeps no other value across
  statements (SOCK_$PUT's result tested at once; the other registers
  copies of the parameters' slots).  Locals of the original held in
  registers would keep slots, as would a `with' temporary.  Stand-ins
  `unused_48' and `unused_4c', two longwords: the bytes do not start at
  a multiple of 8 from A6, where an object of 8 bytes or more is placed,
  so the original's objects there were smaller. }

procedure app_$demux(in pkt: xns_$pkt_desc_t; in port_type: integer;
                     in port_socket: integer; in mac_broadcast: boolean;
                     out status: status_$t);
var
  rec: sock_$pkt_info_t;
  app_hdr: app_$pkt_hdr_ptr_t;
  unused_48: integer32;                   { see the TODO }
  unused_4c: integer32;
begin
  status.all := status_$ok;

  rec.hdr := pkt.header;

  app_hdr := app_$pkt_hdr_ptr_t(rec.hdr + xns_idp_header_size);

  if not ((app_hdr^.p_src_node = 2) and then (app_hdr^.p_src_sock = 4)
          and then app_hdr^.p_net_type and then mac_broadcast) then begin
    rec.flags := [sock_pkt_flag_xns];
    if mac_broadcast then
      rec.flags := rec.flags + [sock_pkt_flag_demux_bool];

    rec.src_addr := pkt.mac_src_hi;
    rec.src_port := pkt.mac_src_lo;
    rec.hdr_len := pkt.data_len;
    rec.data_len := pkt.port_info;
    rec.data_pages := pkt.mac_info;
    rec.n_hops := 0;

    if sock_$put(app_hdr^.p_src_sock, rec, false, port_type, port_socket) then
      return;

    if app_hdr^.p_src_sock = app_sock_type_file then begin
      ring_$file_overflow := ring_$file_overflow + 1;
      if sock_$put(app_sock_type_overflow, rec, false, port_type,
                   port_socket) then
        return;
      ring_$overflow_overflow := ring_$overflow_overflow + 1;
    end;
  end;

  netbuf_$rtn_hdr(rec.hdr);

  if rec.data_pages[1] <> 0 then
    pkt_$dump_data(rec.data_pages, rec.data_len);
end;
