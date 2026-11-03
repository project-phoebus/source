{ IIC_$SEND_OS - send a packet for MAC_OS (the driver's send_os).

  Image addresses:
    sau3  0x00E85F48  IIC_$SEND_OS

  - On a line that is up, through an open channel, with at most 484
    bytes of header and 1024 of data and a two-word link address.  The
    header is built in a network header buffer (a new one unless the
    caller's header already sits 28 bytes into one); a packet to another
    node, or to all, goes out by IIC_$SENDP under the NET_IO lock, one to
    this node, or to all, is looped back to MAC_OS_$DEMUX.

  Status stored:
    status_$iic_remote_device_not_acquired: the other end is down
    status_$iic_device_not_acquired: the line is free
    status_$iic_operation_aborted: no such open channel, or a header,
      data length or link address the line cannot take
    IIC_$SENDP's status: the packet was sent, or not
    status_$ok: the packet was for this node only
}

[section(iic_aqwrd_proc, iic_aqwrd_data)]
procedure iic_$send_os(line: integer; var callback_data: integer;
                       var pkt: mac_os_$send_pkt_t;
                       out bytes_sent: integer; out status: status_$t);
  options(val_param);
var
  pkt_copy: mac_os_$rcv_pkt_t;
  new_pages: pkt_$data_pages_t;
  new_hdr: integer32;
  copy_dst: integer32;
  copy_src: integer32;
  status2: status_$t;
  hdr_va: pkt_$hdr_ptr_t;
  data_desc: pkt_$data_pages_t;
  hdr_pa: integer32;
  result: pinteger;
  send_opts: integer;
  demux_flag: boolean;
  copy_len: pinteger;
  hdr: iic_$frame_hdr_ptr_t;
  hdr_len: integer;
  page: integer32;
  hdr_allocated: boolean;
begin
  send_opts := 0;
  bytes_sent := 0;
  data_desc[1] := pkt.data_pages[1];

  { the line, the channel, the header }
  with iic_lines[line] do begin
    case state of
      iic_line_remote_down: begin
        status.all := status_$iic_remote_device_not_acquired;
        counts.remote_not_acquired := counts.remote_not_acquired + 1;
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
    if (callback_data = 0) or else (callback_data > 4) or else
       not slots[callback_data].open or else
       (pkt.hdr_desc.length > 484) then begin
      status.all := status_$iic_operation_aborted;
      return;
    end;

    { room for the frame header }
    hdr_allocated := false;
    if (pkt.hdr_desc.address & 16#3FF) <> 16#1C then begin
      hdr_allocated := true;
      netbuf_$get_hdr(hdr_pa, data_desc[2]);
      hdr_va := pkt_$hdr_ptr_t(data_desc[2]);
      copy_src := pkt.hdr_desc.address;
      copy_dst := data_desc[2] + 16#1C;
      copy_len := pkt.hdr_desc.length;
      os_$data_copy(pkt_$bytes_ptr_t(copy_src)^, pkt_$bytes_ptr_t(copy_dst)^,
                    copy_len);
    end
    else begin
      page := pkt.hdr_desc.address & 16#FFFFFC00;
      hdr_pa := netbuf_$hdr_page_ptr_t(page)^.phys;
      hdr_va := pkt_$hdr_ptr_t(page);
    end;

    hdr_len := 28 + pkt.hdr_desc.length;
    if pkt.data_length > 1024 then begin
      status.all := status_$iic_operation_aborted;
      return;
    end;
    hdr := iic_$frame_hdr_ptr_t(hdr_va);
    if pkt.link_addr.n_words = 2 then
      hdr^.dest_node := iic_$long_ptr_t(addr(pkt.link_addr.addr[0]))^
    else begin
      status.all := status_$iic_operation_aborted;
      return;
    end;

    { the frame header }
    hdr^.flag_bits.info_flags := 1;
    if pkt.is_broadcast then
      hdr^.flag_bits.info_bits := hdr^.flag_bits.info_bits + [pkt_$hdr_broadcast];
    hdr^.flag_bits.arrival_lo := 0;
    hdr^.flag_bits.flags_07 := [];
    hdr^.src_node := node_$me;
    with hdr^ do begin
      zero_0d := 1;
      total_len := hdr_len;
      data_len := pkt.data_length;
    end;
    hdr^.frame_type := pkt.frame_type;

    { to another node, or to all }
    if (hdr^.dest_node <> hdr^.src_node)
       or else (pkt_$hdr_broadcast in hdr^.flag_bits.info_bits) then begin
      ml_$lock(ml_$net_io_lock);
      iic_$sendp(line, hdr_pa, hdr_va, hdr_len, data_desc, 0,
                 pkt.data_length, send_opts, result, status2);
      bytes_sent := result;
      status := status2;
      ml_$unlock(ml_$net_io_lock);
    end
    else
      status.all := 0;

    { to this node, or to all: loop it back }
    if (hdr_va^.dest_node = hdr_va^.src_node)
       or else (pkt_$hdr_broadcast in hdr_va^.flag_bits.info_bits) then begin
      data_desc[3] := 0;
      pkt_copy := mac_os_$rcv_pkt_t(pkt);
      net_io_$copy_packet(hdr_va, hdr_len, data_desc[3],
                          data_desc, pkt_copy.data_len, new_hdr, new_pages,
                          status2);
      if status2.all = 0 then begin
        pkt_copy.body := new_hdr + 16#1C;
        pkt_copy.data_pa := new_pages;
        demux_flag := false;
        mac_os_$demux(pkt_copy, iic_port[line], demux_flag, status2);
        if status2.all <> 0 then begin
          netbuf_$rtn_hdr(new_hdr);
          pkt_$dump_data(new_pages, pkt_copy.data_len);
        end;
      end;
    end;

    if hdr_allocated then
      netbuf_$rtn_hdr(data_desc[2]);
  end;
end;
