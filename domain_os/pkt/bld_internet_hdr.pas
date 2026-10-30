{ PKT_$BLD_INTERNET_HDR - build a Domain internet packet header.

  Image addresses:
    sau2  0x00E1202C  PKT_$BLD_INTERNET_HDR

  - An internet packet's next hop is RIP_$FIND_NEXTHOP's, the lengths
    checked against the route (this node, a port, or a gateway); a
    local packet gets its destination and socket.
  - The retry limit 5 and the timeout 4 are handed back.
  - A length check's status does not stop the internet part from being
    filled in.
  - The template copy's `template_len > 0' is signed.

  Status stored:
    status_$ok: the header was built
    rip_$find_nexthop's status: no route
    status_$network_data_length_too_large: the data exceed the route's
      limit
    status_$network_request_denied_by_local_node: the port is not active
    status_$network_msg_exceeds_max_size: the template and data exceed it
    status_$network_msg_header_too_big: the header exceeds 952 bytes
    status_$network_header_data_length_exceeds_max: the template does
      not fit behind it
}

{ template_len is a pinteger (every other use treats it as unsigned:
  the zero-extensions for the 32-bit sums and the unsigned compare of
  the word sum hdr_size + template_len + 30), and its `> 0' before the
  template copy is a test and a signed branch: the original compiler
  compares a 0..65535 word with 0 by signed branches. }

procedure pkt_$bld_internet_hdr(routing_key: integer32;
                                dest_node: linteger;
                                dest_sock: integer;
                                src_node_or: integer32;
                                src_node: linteger;
                                src_sock: integer;
                                in pkt_info: univ pkt_$info_t;
                                request_id: pinteger;
                                in template: univ pkt_$hdr_t;
                                template_len: pinteger;
                                data_len: pinteger;
                                in out port_out: integer;
                                out hdr: univ pkt_$hdr_t;
                                out len_out: integer;
                                out retry_hint: integer;
                                out timeout_out: pinteger;
                                out status_ret: status_$t);
  options(val_param);
var
  nexthop_node: integer32;
  hops: integer;
  nexthop: rip_$nexthop_t;
  port: route_$port_ptr_t;
  dest_addr: rip_$dest_addr_t;
  drv: net_io_$driver_ptr_t;
  port_state: integer;
  hdr_size: pinteger;
  total_len: pinteger;
  template_off: pinteger;
  eff_dest: linteger;
  unused_38: array[1..8] of char;         { stand-in }
begin
  if network_$loopback_flag then
    eff_dest := node_$me
  else
    eff_dest := dest_node;
  status_ret.all := status_$ok;

  { the fixed part }
  hdr.flag_bits.info_flags := pkt_info.flags;
  hdr.flag_bits.arrival_lo := 0;
  hdr.flag_bits.flags_07 := [];
  hdr.src_node := node_$me;
  hdr.src_node_lo := hdr.src_node;
  hdr.src_sock := src_sock;

  if pkt_info.routing_type = pkt_$routing_inet then begin
    { the next hop }
    dest_addr.network := routing_key;
    dest_addr.host_node := eff_dest;
    hops := rip_$find_nexthop(dest_addr, false, port_out, nexthop,
                              status_ret);
    nexthop_node := nexthop.host_lo & 16#FFFFF;

    { the lengths for the route }
    if status_ret.all = status_$ok then begin
      if eff_dest = node_$me then begin
        if data_len > 4096 then
          status_ret.all := status_$network_data_length_too_large;
      end
      else if hops = 0 then begin
        port := route_$portp[port_out];
        port_state := port^.active;
        if (port_state = 1) or (port_state = 0) then
          status_ret.all := status_$network_request_denied_by_local_node
        else begin
          drv := net_io_$driver_ptr_t(port^.driver_info);
          if data_len > drv^.max_data_len then
            status_ret.all := status_$network_data_length_too_large
          else if template_len + data_len > drv^.max_data_len + 256 then
            status_ret.all := status_$network_msg_exceeds_max_size;
        end;
      end
      else begin
        if data_len > 1024 then
          status_ret.all := status_$network_data_length_too_large
        else if template_len + data_len > 1280 then
          status_ret.all := status_$network_msg_exceeds_max_size;
      end;
    end;

    { the internet part }
    hdr.dest_node := nexthop_node;
    hdr.hdr_size := 40;
    hdr.route_count := 4;
    hdr.inet_src_sock := src_sock;
    hdr.inet_src_node := node_$me;
    hdr.inet_dest_node_lo := eff_dest;
    hdr.inet_dest_sock := dest_sock;
    hdr.info_0c := pkt_info.field_0c;
    hdr.tpl_len_x := template_len + 30;
    hdr.info_0b := pkt_info.field_0a;
    hdr.protocol := pkt_info.protocol;

    hdr.dest.net := routing_key;
    hdr.dest.zero := 0;
    hdr.dest.node := dest_node;
    hdr.dest.sock := dest_sock;

    if src_node_or = -1 then
      hdr.src.net := route_$port[port_out].network
    else
      hdr.src.net := src_node_or;
    hdr.src.zero := 0;
    hdr.src.node := src_node;
    hdr.src.sock := src_sock;

    { the long request id and address }
    if pkt_info.addr_type = pkt_$addr_long then begin
      hdr.long_request_id := request_id;
      hdr.subtype := pkt_info.protocol;
      hdr.protocol := 4;
      hdr.hdr_size := hdr.hdr_size + 6;
      if hdr.subtype = pkt_$subtype_long_addr then begin
        hdr.addr := pkt_info.addr;
        hdr.hdr_size := hdr.hdr_size + 16;
      end;
    end;
  end

  else if pkt_info.routing_type = pkt_$routing_local then begin
    hdr.dest_node := eff_dest;
    hdr.hdr_size := 4;
    hdr.route_count := 1;
    hdr.local_dest_node_lo := eff_dest;
    hdr.local_dest_sock := dest_sock;
    port_out := 0;
  end;

  { the common words }
  hdr.routing_type := pkt_info.routing_type;
  hdr.zero_0d := 0;
  hdr.zero_0f := 0;
  hdr.flags_0e := pkt_info.flags;
  hdr.template_len := template_len;
  hdr.pkt_data_len := data_len;
  hdr.request_id := request_id;
  hdr_size := hdr.hdr_size;
  total_len := hdr_size + template_len + 30;
  hdr.total_len := total_len;

  if total_len > 952 then begin
    status_ret.all := status_$network_msg_header_too_big;
    return;
  end;

  { the template behind the header }
  len_out := total_len;
  if template_len > 0 then begin
    template_off := hdr_size + 31;
    if template_off + template_len >= 952 then begin
      status_ret.all := status_$network_header_data_length_exceeds_max;
      return;
    end;
    os_$data_copy(template, pkt_$bytes_ptr_t(addr(hdr))^[template_off],
                  template_len);
  end;

  retry_hint := 5;
  timeout_out := 4;
end;
