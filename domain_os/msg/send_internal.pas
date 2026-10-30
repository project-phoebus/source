{ MSG_$$SEND - build a message's packet header and queue it on a local
  socket or hand it to the network.

  Image addresses:
    sau2  0x00E0D9EC  MSG_$$SEND

  - PKT_$BLD_INTERNET_HDR builds the header; an explicit port overrides
    the builder's, its "unknown network" forgiven when the data fit.
  - For this node the packet goes on the socket (SOCK_$PUT); for another
    NET_IO_$SEND sends it under ml_$net_io_lock, up to 1024 bytes of
    data through the bounce page when it is free.

  Status stored:
    net_io_$send's status: another node
    status_$ok or pkt_$copy_to_pa's status: this node, or the data pages
      failed for another
    status_$network_msg_header_too_big: a template over 512 bytes
    pkt_$bld_internet_hdr's status: the header could not be built
    status_$network_data_length_too_large or _msg_exceeds_max_size: the
      data do not fit the explicit port
}

procedure msg_$$send(port_num: integer;
                     routing_key: integer32;
                     dest_node: linteger;
                     dest_sock: pinteger;
                     src_node_or: integer32;
                     src_node: linteger;
                     src_sock: pinteger;
                     in pkt_info: msg_$template_t;
                     request_id: pinteger;
                     in template: univ pkt_$bytes_t;
                     template_len: pinteger;
                     in data: univ pkt_$bytes_t;
                     data_len: pinteger;
                     out send_info: msg_$send_info_t;
                     out status_ret: status_$t);
  options(val_param);
label
  release;
var
  local_pkt: record
    case integer of
      1: (info: sock_$pkt_info_t);
      2: (pkt_hdr: integer32;
          arrival: time_$clock_t);
  end;
  info: record
    case integer of
      1: (tpl: msg_$template_t);
      2: (pkt: pkt_$info_t);
  end;
  data_pages: pkt_$data_pages_t;
  hdr: pkt_$hdr_ptr_t;
  net_info: net_io_$send_info_t;
  data_va: integer32;
  hdr_cell: record
    case integer of
      1: (va: integer32);
      2: (ptr: pkt_$hdr_ptr_t);
  end;
  drv: net_io_$driver_ptr_t;
  hdr_pa: integer32;
  status: status_$t;
  used_dpage: boolean;
  resp_timeout: pinteger;
  retry_hint: integer;
  flags: integer;
  hdr_len: integer;                       { held, with its home slot }
  port: integer;                          { held, with its home slot }
  i: integer;                             { not formed }
begin
  data_pages[1] := 0;
  if template_len > msg_max_template_len then begin
    status_ret.all := status_$network_msg_header_too_big;
    return;
  end;

  { the header }
  info.tpl := pkt_info;
  info.tpl.flags := info.tpl.flags + [msg_info_flag_msg];
  netbuf_$get_hdr(hdr_pa, hdr_cell.va);
  hdr := hdr_cell.ptr;
  pkt_$bld_internet_hdr(routing_key, dest_node, dest_sock, src_node_or,
                        src_node, src_sock, info.pkt, request_id,
                        template, template_len, data_len, port, hdr^,
                        hdr_len, retry_hint, resp_timeout, status);

  { an explicit port }
  if port_num <> -1 then begin
    port := port_num;
    if status.all = status_$network_unknown_network then begin
      status.all := status_$ok;
      drv := net_io_$driver_ptr_t(route_$portp[port]^.driver_info);
      if data_len > drv^.max_data_len then
        status.all := status_$network_data_length_too_large
      else if data_len + hdr_len > drv^.max_data_len + 16#100 then
        status.all := status_$network_msg_exceeds_max_size;
    end;
  end;
  if status.all <> status_$ok then
    goto release;

  send_info.port_net := route_$portp[port]^.port_type;
  send_info.xmit.bits := [];

  { this node }
  if dest_node = node_$me then begin
    if data_len <> 0 then
      pkt_$copy_to_pa(data, data_len, data_pages, status_ret)
    else
      status_ret.all := status_$ok;
    send_info.xmit.local := true;
    if status_ret.all = status_$ok then begin
      local_pkt.info.hdr := integer32(hdr);
      local_pkt.info.hdr_len := hdr_len;
      local_pkt.info.data_len := data_len;
      local_pkt.info.n_hops := 0;
      time_$abs_clock(local_pkt.arrival);
      local_pkt.info.flags := [];
      for i := 1 to 4 do
        local_pkt.info.data_pages[i] := data_pages[i];
      send_info.xmit.queued := sock_$put(dest_sock, local_pkt.info, true,
                                         route_$port[0].port_type,
                                         route_$port[0].socket);
    end;
    if msg_xmit_queued in send_info.xmit.bits then
      return;
    netbuf_$rtn_hdr(hdr_cell.va);
    pkt_$dump_data(data_pages, data_len);
    return;
  end;

  { another node, the data }
  used_dpage := false;
  if data_len <> 0 then begin
    dpage_lock := dpage_lock + 1;
    if (dpage_lock = 0) and then (data_len <= msg_dpage_max_data) then begin
      used_dpage := true;
      data_va := dpage_va;
      data_pages[1] := dpage_pa;
      os_$data_copy(data, pkt_$bytes_ptr_t(data_va)^, data_len);
    end
    else begin
      dpage_lock := dpage_lock - 1;
      pkt_$copy_to_pa(data, data_len, data_pages, status);
      if status.all <> status_$ok then
        goto release;
      data_va := 0;
    end;
  end
  else
    data_va := 0;

  { the send }
  flags := 0;
  ml_$lock(ml_$net_io_lock);
  net_io_$send(port, hdr_cell.ptr, hdr_pa, hdr_len, data_va, data_pages,
               data_len, flags, net_info, status);
  ml_$unlock(ml_$net_io_lock);
  send_info := msg_$send_info_t(net_info);

release:
  netbuf_$rtn_hdr(hdr_cell.va);
  if used_dpage then
    dpage_lock := dpage_lock - 1
  else
    pkt_$dump_data(data_pages, data_len);
  status_ret := status;
end;
