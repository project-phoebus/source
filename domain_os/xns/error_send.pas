{ XNS_ERROR_$SEND - answer an undeliverable packet with an XNS error
  packet.

  Image addresses:
    sau2  0x00E17960  xns_$setup_error_header (nested)
    sau2  0x00E17A2E  XNS_ERROR_$SEND

  - Under a cleanup handler the error channel is opened for one more
    user and the error packet built in a network header buffer: the
    error words and up to 42 bytes of the offending packet (the nested
    xns_$setup_error_header), back to its source; it is then sent.
  - Every refusal returns without FIM_$RLS_CLEANUP.

  Status stored:
    xns_idp_$os_send's status: the error packet was sent, or not
    status_$xns_error_illegal_buffer_spec: a packet shorter than an IDP
      header, or with none
    status_$xns_error_source_is_broadcast: its source or destination
      host is the broadcast host
    status_$xns_error_packet_type_error: it is an error packet itself
    maybe_open_error_socket's or netbuf_$getva's status: those failed
    the fault's status: a fault unwound to the handler
}

{ TODO(pascal) 4 frame bytes of XNS_ERROR_$SEND no object explains

  With the locals in the order declared (each register-held one with
  its slot), the two `with' temporaries and the
  `or''s temporary below them (item 4),
  the SAU2 frame has one longword that holds no object the code
  addresses: the stand-in unused_40.  The order of the temporaries is
  not settled (the `or''s comes first in the code but lies lowest). }

procedure xns_error_$send(in pkt: xns_$pkt_desc_t; in code: integer;
                          in param: integer; out result_ret: integer;
                          out status: status_$t);
var
  cleanup_rec: fim_$cleanup_rec_t;
  open_status: status_$t;
  cleanup_status: status_$t;
  hdr: xns_$idp_header_ptr_t;
  netbuf_va: integer32;
  netbuf_handle: integer32;
  epkt: xns_$error_pkt_ptr_t;
  packet_info_2: xns_$pkt_desc_ptr_t;
  remaining: integer;
  bcast: boolean;
  socket_opened: boolean;
  in_netbuf_pool: boolean;
  unused_40: integer32;                   { stand-in }

  { xns_$setup_error_header - copy the head of the offending packet into
    the error packet.

    - Up to 42 bytes, after the error packet's IDP header and its two
      words, from the chain's buffers, or from the packet's pages when
      they lie in the network buffer window.

    Status stored (in the parent's status):
      none: the bytes were copied
      netbuf_$getva's status: a page could not be mapped
  }

  procedure xns_$setup_error_header;
  var
    dst_va: integer32;                    { stored from D0 }
    src_va: integer32;
    fetched_va: integer32;                { held, with its slot }
    dst_off: integer;
    chunk: integer;
    node: xns_$buf_desc_ptr_t;
  begin
    fetched_va := 0;
    remaining := 16#2A;
    dst_off := 16#22;
    node := addr(pkt.head);

    { the copy the first branch reaches }
    src_va := node^.address;
    chunk := remaining;
    if chunk > node^.length then
      chunk := node^.length;

    while (remaining <> 0) and then (src_va <> 0) do begin
      dst_va := dst_off + netbuf_va;
      os_$data_copy(pkt_$bytes_ptr_t(src_va)^, pkt_$bytes_ptr_t(dst_va)^,
                    chunk);
      dst_off := dst_off + chunk;
      remaining := remaining - chunk;
      if remaining <> 0 then
        if in_netbuf_pool then begin
          chunk := remaining;
          if chunk > packet_info_2^.netbuf_len then
            chunk := packet_info_2^.netbuf_len;
          netbuf_$getva(packet_info_2^.netbuf_handle, fetched_va, status);
          src_va := fetched_va;
        end
        else begin
          node := node^.next;
          if node = nil then
            src_va := 0
          else begin
            src_va := node^.address;
            chunk := remaining;
            if chunk > node^.length then
              chunk := node^.length;
          end;
        end;
    end;

    if fetched_va <> 0 then
      discard(netbuf_$rtnva(fetched_va));
  end;

begin
  netbuf_handle := 0;
  result_ret := 0;
  status.all := status_$ok;
  socket_opened := false;

  cleanup_status := fim_$cleanup(cleanup_rec);
  if cleanup_status.all = fault_$cleanup_set then begin
    packet_info_2 := addr(pkt);
    if (pkt.data_len < xns_idp_header_size) or else (pkt.header = 0) then
    begin
      status.all := status_$xns_error_illegal_buffer_spec;
      return;
    end;

    hdr := xns_$idp_header_ptr_t(pkt.header);
    bcast := xns_$is_local_addr(hdr^.src) or xns_$is_local_addr(hdr^.dest);
    if bcast then begin
      status.all := status_$xns_error_source_is_broadcast;
      return;
    end;

    if hdr^.packet_type = xns_idp_type_error then begin
      status.all := status_$xns_error_packet_type_error;
      return;
    end;

    maybe_open_error_socket(open_status);
    status := open_status;
    if status.all <> status_$ok then
      return;
    socket_opened := true;

    netbuf_$get_hdr(netbuf_handle, netbuf_va);
    epkt := xns_$error_pkt_ptr_t(netbuf_va);
    in_netbuf_pool := xns_$pkt_bufs_in_netbuf_pool(pkt);
    xns_$setup_error_header;

    xns_error_$send_rec.hdr_desc.length := 76 - remaining;
    xns_error_$send_rec.hdr_desc.address := integer32(epkt);
    xns_error_$send_rec.hdr_desc.next := nil;
    xns_error_$send_rec.hdr_prebuilt := true;

    with epkt^.idp do begin
      checksum := 16#FFFF;
      length := xns_error_$send_rec.hdr_desc.length;
      transport_ctl := 0;
      packet_type := xns_idp_type_error;
      dest := epkt^.orig_hdr.src;
      src.socket := xns_socket_error;
      src.network := 0;
      src.host[0] := 16#800;
      src.host[1] := (rshft(node_$me, 16) & 16#F) ! 16#1E00;
      src.host[2] := node_$me;
    end;

    with epkt^ do begin
      error_param := param;
      error_code := code;
    end;

    xns_idp_$os_send(xns_error_$std_idp_channel, xns_error_$send_rec,
                     result_ret, status);
    maybe_close_error_socket;
    fim_$rls_cleanup(cleanup_rec);
  end

  else begin
    if netbuf_handle <> 0 then
      netbuf_$rtn_hdr(netbuf_va);
    if socket_opened then
      maybe_close_error_socket;
    status := cleanup_status;
  end;
end;
