{ XNS_IDP_$OS_SEND - send an IDP packet on a channel (the OS's call).

  Image addresses:
    sau2  0x00E18256  XNS_IDP_$OS_SEND

  - Under a cleanup handler a header the channel builds gets the length,
    the packet type and the addresses (the channel's when connected).
  - A connected channel sends to its link address; any other finds the
    next hop (RIP) and its link address (MAC_OS_$ARP).
  - The checksum is computed unless the header says none, and the
    packet goes out on the port's MAC channel.
  - On a connected channel MAC's record's is_broadcast is not set.

  Status stored:
    mac_os_$send's status: the packet was sent, or not
    status_$xns_illegal_buffer_spec (16#3B0008): a negative length, or a
      length with no address
    status_$xns_network_unreachable (16#3B0013): no next hop
    status_$xns_bad_checksum (16#3B0011): the checksum could not be made
    the callees' statuses: RIP, MAC_OS_$ARP or the bind failed
    the fault's status: a fault unwound to the handler
}

{ TODO(pascal) 12 frame bytes of XNS_IDP_$OS_SEND no object explains

  With the locals in the order declared, the SAU2 frame has 4 bytes
  between port's slot and port_num (the stand-in unused_9e), and 8
  between port_num and the `with''s temporary (the stand-in unused_a8).
  The two 8-alignments the reading needs (nexthop, spkt) are not dpc's: dpc
  places them 6 and 4 bytes higher, and so every object below them. }

procedure xns_idp_$os_send(in channel: pinteger;
                           in rec: xns_$os_send_rec_t;
                           out len_sent: integer;
                           out status: status_$t);
label
  10;
var
  hdr: xns_$idp_header_ptr_t;
  dest_addr: xns_$addr_t;
  cleanup_rec: fim_$cleanup_rec_t;
  nexthop: rip_$nexthop_t;
  spkt: mac_os_$send_pkt_t;
  connected: boolean;
  build: boolean;
  total: integer32;
  buf: mac_os_$buf_desc_ptr_t;
  cleanup_status: status_$t;
  port: integer;
  unused_9e: array[1..2] of integer;      { stand-in }
  port_num: integer;
  unused_a8: array[1..2] of integer32;    { stand-in }
begin
  len_sent := 0;
  status.all := status_$ok;

  cleanup_status := fim_$cleanup(cleanup_rec);
  if cleanup_status.all = fault_$cleanup_set then begin
    hdr := xns_$idp_header_ptr_t(rec.hdr_desc.address);
    with xns_idp_$channels[channel] do begin
      connected := xns_chan_flag_connect in flags.members;
      build := xns_chan_flag_build_header in flags.members;
      if build then begin
        hdr^.checksum := 16#FFFF;
        buf := rec.hdr_desc.next;
        total := rec.hdr_desc.length;
        while buf <> nil do begin
          if (buf^.length < 0)
             or else ((buf^.length > 0) and then (buf^.address = 0)) then
          begin
            fim_$rls_cleanup(cleanup_rec);
            status.all := status_$xns_illegal_buffer_spec;
            return;
          end;
          total := total + buf^.length;
          buf := buf^.next;
        end;
        hdr^.length := total + rec.data.length;
        hdr^.transport_ctl := 0;
        hdr^.packet_type := rec.packet_type;
        if connected then begin
          hdr^.dest := dest;
          hdr^.src := src;
        end
        else
          hdr^.addrs := rec.addrs;
      end;

      if connected then begin
        port := connected_port;
        spkt.link_addr := mac_info;
      end
      else begin
        dest_addr := hdr^.dest;
        discard(rip_$find_nexthop(dest_addr, true, port_num, nexthop,
                                  status));
        port := port_num;
        if status.all <> status_$ok then
          goto 10;
        if port = -1 then begin
          fim_$rls_cleanup(cleanup_rec);
          status.all := status_$xns_network_unreachable;
          return;
        end;
        mac_os_$arp(nexthop, port, spkt.link_addr, spkt.is_broadcast,
                    status);
        if status.all <> status_$ok then
          goto 10;
      end;
    end;

    xns_$add_port(channel, port, status);
    if status.all <> status_$ok then
      goto 10;

    spkt.frame_type := xns_mac_frame_type;
    spkt.hdr_desc := rec.hdr_desc;
    spkt.hdr_prebuilt := rec.hdr_prebuilt;
    spkt.data := rec.data;

    if hdr^.checksum <> 16#FFFF then begin
      hdr^.checksum := xns_$get_checksum(spkt);
      if hdr^.checksum = 16#FFFF then begin
        fim_$rls_cleanup(cleanup_rec);
        status.all := status_$xns_bad_checksum;
        return;
      end;
    end;

    mac_os_$send(xns_idp_$port_table[port].mac_socket, spkt, len_sent,
                 status);
    if status.all = status_$ok then
      xns_idp_$packets_sent := xns_idp_$packets_sent + 1;

10:
    fim_$rls_cleanup(cleanup_rec);
  end

  else
    status := cleanup_status;
end;
