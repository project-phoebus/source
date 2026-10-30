{ NET_IO_$SEND - send a packet on a network port.

  Image addresses:
    sau2  0x00E0E692  NET_IO_$SEND

  - A packet to this node is copied and delivered here (loopback).  An
    internet broadcast on the port's own network is delivered locally
    too; to another network it becomes an all-ones destination.
  - The packet is counted, logged when ring logging is on, and handed to
    the port's driver.
  - The loopback path ORs 16#8008 into the caller's xmit_status.

  Status stored:
    the driver's status: the packet was handed on
    net_io_$copy_packet's status: a loopback packet
    status_$internet_unknown_network_port: a port outside 0..7
    status_$internet_network_port_not_open: the port is not active
    status_$network_request_denied_by_local_node: the port is active as 1
    status_$network_transmit_with_invalid_from_id: an all-ones source
}

procedure net_io_$send(port: integer; var hdr_ptr: pkt_$hdr_ptr_t;
                       hdr_pa: integer32; hdr_len: integer;
                       data_va: integer32;
                       in data_pages: univ net_io_$data_pages_t;
                       data_len: integer; flags: integer;
                       out send_info: net_io_$send_info_t;
                       out status_ret: status_$t);
  options(val_param);
var
  copy_pages: pkt_$data_pages_t;
  deliver_out: ec_$eventcount_ptr_t;
  p: route_$port_ptr_t;
  hdr: pkt_$hdr_ptr_t;
  copy_hdr: integer32;
  drv_status: status_$t;
  drv: net_io_$driver_ptr_t;
  log_index: integer;
begin
  if (port < 0) or else (port > 7) then begin
    status_ret.all := status_$internet_unknown_network_port;
    return;
  end;
  p := route_$portp[port];
  if p^.active = 0 then begin
    status_ret.all := status_$internet_network_port_not_open;
    return;
  end;
  if p^.active = 1 then begin
    status_ret.all := status_$network_request_denied_by_local_node;
    return;
  end;

  hdr := hdr_ptr;
  if hdr^.dest_node = node_$me then begin
    net_io_$copy_packet(hdr_ptr, hdr_len, data_va, data_pages, data_len,
                        copy_hdr, copy_pages, status_ret);
    if status_ret.all = status_$ok then begin
      p := addr(route_$port[0]);
      discard(net_io_$put_in_sock_common(p, p^.port_type, p^.socket,
                                         false, copy_hdr, copy_pages,
                                         hdr_len, data_len, deliver_out));
    end;
    send_info.port_net := 0;
    send_info.xmit_status := send_info.xmit_status ! 16#8008;
    return;
  end;

  if hdr^.routing_type <> pkt_$routing_local then
    with hdr^ do begin
      if (src.node & net_io_$all_f_addr) = net_io_$all_f_addr then begin
        status_ret.all := status_$network_transmit_with_invalid_from_id;
        return;
      end;
      if (dest.net = p^.network) or else (dest.net = 0) then begin
        if (dest.node & net_io_$all_f_addr) = net_io_$all_f_addr then begin
          dest_node := 0;
          flag_bits.info_bits := flag_bits.info_bits
                                 + [pkt_$hdr_broadcast];
        end;
        if (info_0b <> 0)
           and then (pkt_$hdr_broadcast in flag_bits.info_bits) then begin
          net_io_$copy_packet(hdr_ptr, hdr_len, data_va, data_pages,
                              data_len, copy_hdr, copy_pages, status_ret);
          if status_ret.all = status_$ok then
            discard(net_io_$put_in_sock_common(p, p^.port_type, p^.socket,
                                               false, copy_hdr,
                                               copy_pages, hdr_len,
                                               data_len, deliver_out));
        end;
      end
      else if pkt_$hdr_broadcast in flag_bits.info_bits then begin
        flag_bits.info_bits := flag_bits.info_bits - [pkt_$hdr_broadcast];
        dest.node := 16#FFFFFF;
      end;
    end;

  send_info.port_net := p^.port_type;
  send_info.xmit_status := 0;
  status_ret.all := status_$ok;
  p^.forward_count := p^.forward_count + 1;
  if ring_$logging_now then
    log_index := ringlog_$logit(false, hdr_ptr^)
  else
    log_index := -1;

  drv := net_io_$driver_ptr_t(p^.driver_info);
  if drv^.sendp = nil then
    drv_status.all := status_$ok
  else
    drv^.sendp^(p^.socket, hdr_pa, hdr_ptr, hdr_len, data_pages, data_va,
                data_len, flags, send_info.xmit_status, drv_status);
  status_ret := drv_status;

  if log_index <> -1 then
    ringlog_$data.entries[log_index].xmit_status := send_info.xmit_status;
end;
