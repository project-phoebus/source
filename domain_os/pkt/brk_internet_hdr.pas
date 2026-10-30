{ PKT_$BRK_INTERNET_HDR - take a received packet header apart.

  Image addresses:
    sau2  0x00E12328  PKT_$BRK_INTERNET_HDR

  - The flags, routing type, request id and template length, then a
    local or an internet header's addresses (two separate tests) and the
    protocol or long address.
  - The template is copied out, no more than the caller's maximum.

  Status stored:
    status_$ok: the header was taken apart
    status_$network_header_data_length_exceeds_max: the template does
      not fit a 952-byte buffer
}

procedure pkt_$brk_internet_hdr(in hdr: pkt_$hdr_t;
                                hdr_len: integer;
                                out routing_key: integer32;
                                out dest_node: integer32;
                                out dest_sock: pinteger;
                                out src_node_or: integer32;
                                out src_node: linteger;
                                out src_sock: pinteger;
                                out info_out: pkt_$info_t;
                                out id_out: pinteger;
                                out data_buf: univ pkt_$bytes_t;
                                data_max: pinteger;
                                in out data_len: pinteger;
                                out status_ret: status_$t);
  options(val_param);
var
  routing_type: integer;
  copy_len: pinteger;
begin
  info_out.flags := hdr.flags_0e;
  routing_type := hdr.routing_type;
  info_out.routing_type := routing_type;
  id_out := hdr.request_id;
  data_len := hdr.template_len;
  status_ret.all := status_$ok;

  { a local header }
  if routing_type = pkt_$routing_local then begin
    src_node_or := 0;
    routing_key := 0;
    dest_node := node_$me;
    dest_sock := hdr.route[hdr.route_count + 1];
    if hdr.hdr_size = 4 then begin
      src_sock := hdr.src_sock;
      src_node := hdr.src_node;
    end
    else begin
      src_sock := hdr.inet_src_sock;
      src_node := hdr.inet_src_node;
    end;
  end;

  { an internet header }
  if routing_type = pkt_$routing_inet then begin
    routing_key := hdr.dest.net;
    dest_node := hdr.dest.node;
    dest_sock := hdr.dest.sock;
    src_node_or := hdr.src.net;
    src_node := hdr.src.node;
    src_sock := hdr.src.sock;
    if hdr.protocol = 4 then begin
      info_out.addr_type := pkt_$addr_long;
      info_out.protocol := hdr.subtype;
      if info_out.protocol = 16#29 then
        info_out.addr := hdr.addr;
    end
    else begin
      info_out.addr_type := pkt_$addr_short;
      info_out.protocol := hdr.protocol;
    end;
  end;

  if hdr.hdr_size + 31 + data_len >= 952 then begin
    status_ret.all := status_$network_header_data_length_exceeds_max;
    return;
  end;

  copy_len := min(data_len, data_max);
  os_$data_copy(pkt_$bytes_ptr_t(addr(hdr))^[hdr.hdr_size + 31], data_buf,
                copy_len);
  data_len := copy_len;
end;
