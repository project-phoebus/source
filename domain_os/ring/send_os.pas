{ RING_$SEND_OS - send a MAC_OS packet on a channel (the driver's send_os).

  Image addresses:
    sau2  0x00E77C60  RING_$SEND_OS
    sau4  0x0F8854E0  RING_$SEND_OS
    sau3  0x00E79450  RING_$SEND_OS
    sau8  0x03C8452E  RING_$SEND_OS

  - The ring header goes in front of the caller's, in a fresh header
    page unless the caller's header starts at page offset 0x1C.
  - A packet for another node or for all is sent with RING_$SENDP under
    the NET_IO lock; one for this node or for all is looped back through
    MAC_OS_$DEMUX.
  - A loopback failure is not reported.

  Status stored:
    status_$ok: the packet was looped back only
    ring_$sendp's status: the packet was sent
    status_$ring_device_offline: the unit is not started, or its mask
      lacks bit 0
    status_$ring_channel_not_open: the channel is not 1..10 and open
    status_$ring_illegal_header_length: the header is over 968 bytes
    status_$ring_invalid_data_length: the data is over 1024 bytes
    status_$ring_illegal_dest_address: the link address is not two
      words
}

procedure ring_$send_os(line: integer; var callback_data: integer;
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
  result: ring_$csr_t;
  send_opts: integer;
  demux_flag: boolean;
  hdr: ring_$hdr_ptr_t;
  hdr_allocated: boolean;
  hdr_len: integer;
  page: integer32;
  i: integer;
begin
  send_opts := 0;
  bytes_sent := 0;
  data_desc[1] := pkt.data_pages[1];

  { the unit, the channel, the header }
  with ring_$ctl[line] do begin
    if not (ring_unit_started in state_flags)
       or else not odd(tmask) then begin
      status.all := status_$ring_device_offline;
      return;
    end;
    if (callback_data = 0) or else (callback_data > 10)
       or else not channels[callback_data].flags then begin
      status.all := status_$ring_channel_not_open;
      return;
    end;
  end;
  if pkt.hdr_desc.length > 968 then begin
    status.all := status_$ring_illegal_header_length;
    return;
  end;

  { room for the ring header }
  hdr_allocated := false;
  if (pkt.hdr_desc.address & 16#3FF) <> 16#1C then begin
    hdr_allocated := true;
    netbuf_$get_hdr(hdr_pa, data_desc[2]);
    hdr_va := pkt_$hdr_ptr_t(data_desc[2]);
    copy_src := pkt.hdr_desc.address;
    copy_dst := data_desc[2] + 16#1C;
    hdr_len := pkt.hdr_desc.length;
    os_$data_copy(pkt_$bytes_ptr_t(copy_src)^, pkt_$bytes_ptr_t(copy_dst)^,
                  hdr_len);
  end
  else begin
    page := pkt.hdr_desc.address & 16#FFFFFC00;
    hdr_pa := netbuf_$hdr_page_ptr_t(page)^.phys;
    hdr_va := pkt_$hdr_ptr_t(page);
  end;

  hdr_len := 28 + pkt.hdr_desc.length;
  if pkt.data_length > 1024 then begin
    status.all := status_$ring_invalid_data_length;
    return;
  end;
  hdr := ring_$hdr_ptr_t(hdr_va);
  if pkt.link_addr.n_words = 2 then
    for i := 0 to 1 do
      hdr^.msg_type.words[i] := pkt.link_addr.addr[i]
  else begin
    status.all := status_$ring_illegal_dest_address;
    return;
  end;

  { the ring header }
  hdr^.flags.info_flags := 1;
  if pkt.is_broadcast then
    hdr^.flags.info_bits := hdr^.flags.info_bits + [pkt_$hdr_broadcast];
  hdr^.flags.arrival_lo := 0;
  hdr^.flags.flags_07 := [];
  hdr^.src_id.node := node_$me;
  ring_$hdr_ptr_t(hdr_va)^.chksum := 1;
  ring_$hdr_ptr_t(hdr_va)^.hdr_len := hdr_len;
  ring_$hdr_ptr_t(hdr_va)^.data_len := pkt.data_length;
  ring_$hdr_ptr_t(hdr_va)^.route_info := pkt.frame_type;

  { to another node, or to all }
  if (ring_$hdr_ptr_t(hdr_va)^.msg_type.node
      <> ring_$hdr_ptr_t(hdr_va)^.src_id.node)
     or else (pkt_$hdr_broadcast
              in ring_$hdr_ptr_t(hdr_va)^.flags.info_bits) then begin
    ml_$lock(ml_$net_io_lock);
    ring_$sendp(line, hdr_pa, hdr_va, hdr_len, data_desc, 0,
                pkt.data_length, send_opts, result, status2);
    bytes_sent := integer(result);
    status := status2;
    ml_$unlock(ml_$net_io_lock);
  end
  else
    status.all := 0;

  { to this node, or to all: loop it back }
  if (ring_$hdr_ptr_t(hdr_va)^.msg_type.node
      = ring_$hdr_ptr_t(hdr_va)^.src_id.node)
     or else (pkt_$hdr_broadcast
              in ring_$hdr_ptr_t(hdr_va)^.flags.info_bits) then begin
    data_desc[3] := 0;
    pkt_copy := mac_os_$rcv_pkt_t(pkt);
    net_io_$copy_packet(hdr_va, hdr_len, data_desc[3], data_desc,
                        pkt_copy.data_len, new_hdr, new_pages, status2);
    if status2.all = 0 then begin
      pkt_copy.body := new_hdr + 16#1C;
      pkt_copy.data_pa := new_pages;
      demux_flag := false;
      mac_os_$demux(pkt_copy, ring_$port_array[line], demux_flag, status2);
      if status2.all <> 0 then begin
        netbuf_$rtn_hdr(new_hdr);
        pkt_$dump_data(new_pages, pkt_copy.data_len);
      end;
    end;
  end;

  if hdr_allocated then
    netbuf_$rtn_hdr(data_desc[2]);
end;
