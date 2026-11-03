{ IIC_$RECEIVE - receive a message from a line of the internet interface
  controller.

  Image addresses:
    sau2  0x00E70ABA  IIC_$RECEIVE
    sau3  0x00E71D38  IIC_$RECEIVE

  - Without the driver a stub: the controller is not in the system.  The
    two lengths (the data's, then the header's) are cleared; the others
    are never read.
  - With it, the next packet of the line's socket is waited for (a quit
    ends the wait) under the line's receive lock; its header is taken
    apart into hdr (128 bytes at most), and its data, 1024 bytes at most,
    copied to data through the line's receive page.  A longer packet is
    dropped.

  Status stored:
    status_$iic_device_not_in_system: without the driver
    status_$iic_remote_device_not_acquired: the other end is down
    status_$iic_device_not_acquired: the line is free
    status_$network_data_length_too_large: the packet's data is longer
    status_$iic_no_expected_packet: the socket had no packet
    status_$iic_operation_aborted: a quit ended the wait
    pkt_$brk_internet_hdr's status: the message was received, or not
}

procedure iic_$receive(in line: pinteger; out hdr: univ iic_$msg_t;
                       in out hdr_len: pinteger; out data: univ iic_$msg_t;
                       out data_len: pinteger; out status: status_$t);
%if iic_driver %then
var
  info: sock_$pkt_info_t;
  pkt_info: pkt_$info_t;
  data_pa: integer32;
  src_node: linteger;
  src_node_or: integer32;
  dest_node: integer32;
  routing_key: integer32;
  st: status_$t;
  id: pinteger;
  src_sock: pinteger;
  dest_sock: pinteger;
  pkt_hdr_len: integer;
  pkt_hdr: integer32;
  rx: iic_$page_ptr_t;
%endif
begin
%if iic_driver %then
  with iic_lines[line] do begin
    case state of
      iic_line_remote_down: begin
        status.all := status_$iic_remote_device_not_acquired;
        return;
      end;
      iic_line_free: begin
        status.all := status_$iic_device_not_acquired;
        return;
      end;
      iic_line_up: begin
        status.all := status_$ok;
      end;
    end;

    ml_$exclusion_start(rcv_lock);
    case ec_$wait(addr(sock_$socket_ptr[sock]^.ec),
                  addr(fim_$quit_ec[proc1_$as_id]), addr(ec_$nil_ec),
                  sock_wait, fim_$quit_value[proc1_$as_id] + 1, 0) of
      0: begin
        sock_wait := sock_wait + 1;
        if sock_$get(sock, info) then begin
          pkt_hdr := info.hdr;
          pkt_hdr_len := info.hdr_len;
          data_len := info.data_len;
          data_pa := info.data_pages[1];
          if data_len > 1024 then begin
            netbuf_$rtn_hdr(pkt_hdr);
            pkt_$dump_data(info.data_pages, data_len);
            status.all := status_$network_data_length_too_large;
          end
          else
            status.all := status_$ok;
        end
        else
          status.all := status_$iic_no_expected_packet;
      end;
      1: begin
        status.all := status_$iic_operation_aborted;
      end;
    end;
    ml_$exclusion_stop(rcv_lock);
    if status.all <> status_$ok then
      return;

    pkt_$brk_internet_hdr(pkt_$hdr_ptr_t(pkt_hdr)^, pkt_hdr_len, routing_key,
                          dest_node, dest_sock, src_node_or, src_node,
                          src_sock, pkt_info, id, hdr, 128, hdr_len, st);
    netbuf_$rtn_hdr(pkt_hdr);
    if (st.all = status_$ok) and then (data_len <> 0) then begin
      rx := addr(iic_$control_page[3][line]);
      mmu_$install(rshft(data_pa, 10), rx, 0, 16#16);
      os_$data_copy(rx^, data, data_len);
      mmu_$remove(rshft(data_pa, 10));
      netbuf_$rtn_dat(data_pa);
    end;
    status := st;
  end;
%else
  status.all := status_$iic_device_not_in_system;
  data_len := 0;
  hdr_len := 0;
%endif
end;
