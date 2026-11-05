{ RING_8025_$SEND_OS - send a MAC_OS packet on a system channel.

  Image addresses:
    sau7  0x3C499A92  RING_8025_$SEND_OS
    sau8  0x03C8D05E  RING_8025_$SEND_OS
    sau9  0x3C488C62  RING_8025_$SEND_OS

  - The driver record's send_os entry.  The packet goes out as the
    unit's MAC header in its control area, an LLC and SNAP header after
    the routing field (the packet's frame type its SNAP type), the
    caller's header and the data (from the first data page's physical
    address).
  - The destination: a three-word link address as it is; a two-word
    one, a node ID, as the stations' high half and its low 24 bits.
    With source routing the destination's route is found first
    (ring_8025_find_route) and a routing field marks the source address.
  - The transmit is made under the unit's transmit lock and the NET_IO
    lock; bytes_sent is always 0.

  Status stored:
    ring_8025_transmit's status: the frame was sent, or not
    status_$r8025_invalid_unit_num: line is above 1
    status_$r8025_device_offline: the unit is not on line
    status_$r8025_channel_not_open: the channel is 0, above 10 or not
      open
    status_$r8025_illegal_frame_length: a length is negative, or the
      frame, without a routing field, is longer than the largest the
      ring takes
    status_$r8025_illegal_dest_address: the link address is not two or
      three words
}

procedure ring_8025_$send_os(line: integer; var callback_data: pinteger;
                             var pkt: mac_os_$send_pkt_t;
                             out bytes_sent: integer; out status: status_$t);
  options(val_param);
type
  { A two-word link address: a node ID, its low 24 bits a station's. }
  link_view_t = packed record
    n_words: integer;                     { 0x00 }
    node_high: 0..255;                    { 0x02 }
    node_low: 0..16#FFFFFF;               { 0x03 }
  end;
  link_view_ptr_t = ^link_view_t;
var
  pieces: array[1..5] of ring_8025_$xmit_piece_t;
  ft: ring_8025_$ftype_t;
  st: status_$t;
  fstat: integer;
  rif_len: integer;
  llc: ring_8025_$llc_ptr_t;
  total: integer;
  rlen: integer;
  count: integer;
  i: integer;
begin
  bytes_sent := 0;
  if line > r8025_max_unit then begin
    status.all := status_$r8025_invalid_unit_num;
    return;
  end;
  if not (r8025_unit_online in ring8025_ucb[line].flags) then begin
    status.all := status_$r8025_device_offline;
    return;
  end;
  if (callback_data = 0) or else (callback_data > r8025_max_chan)
     or else not ring8025_ucb[line].channels[callback_data].open then begin
    status.all := status_$r8025_channel_not_open;
    return;
  end;

  { the length: the headers and the data }
  total := pkt.hdr_desc.length + pkt.data_length + 22;
  if (pkt.hdr_desc.length < 0) or else (pkt.data_length < 0)
     or else (total > ring8025_ucb[line].max_frame) then begin
    status.all := status_$r8025_illegal_frame_length;
    return;
  end;

  { the MAC header and the route }
  with ring8025_$aux_da.ctl[line] do begin
    case pkt.link_addr.n_words of
      3: begin
        for i := 0 to 2 do
          xmit_hdr.dest.words[i] := pkt.link_addr.addr[i];
      end;
      2: begin
        xmit_hdr.dest.high := r8025_addr_high;
        xmit_hdr.dest.low := link_view_ptr_t(addr(pkt.link_addr))^.node_low;
      end;
      otherwise begin
        status.all := status_$r8025_illegal_dest_address;
        return;
      end;
    end;
    xmit_hdr.ac := r8025_ac;
    xmit_hdr.fc := r8025_fc_llc;
    xmit_hdr.src.high := r8025_addr_high;
    xmit_hdr.src.low := node_$me;
    if ring8025_ucb[line].routing then begin
      ring_8025_find_route(addr(ring8025_ucb[line]),
                           ring8025_$aux_da.ctl[line].xmit_hdr,
                           r8025_snap_sap, r8025_snap_sap, r8025_llc_ui,
                           rif_len);
      rlen := rif_len;
      if rlen <> 0 then
        xmit_hdr.src.rii := true;
    end
    else
      rlen := 0;
  end;
  total := total + rlen;

  { the LLC and SNAP header after the routing field }
  llc := ring_8025_$llc_ptr_t(
           rlen + integer32(addr(ring8025_$aux_da.ctl[line].xmit_hdr.rif)));
  ft.all := pkt.frame_type;
  llc^.dsap := r8025_snap_sap;
  llc^.ssap := r8025_snap_sap;
  llc^.ctl := r8025_llc_ui;
  llc^.snap_org := r8025_snap_org;
  llc^.snap_type := ft.snap;

  { the pieces: the headers, the caller's header, the data }
  ml_$exclusion_start(ring8025_ucb[line].xmit_lock);
%if ring_8025_iomap %then
  pieces[1].pa := ring_8025_vtop(
                    integer32(addr(ring8025_$aux_da.ctl[line].xmit_hdr)),
                    r8025_xmit_hdr_room,
                    ring8025_ucb[line].iomap_page + r8025_map_ctl);
%else
  pieces[1].pa := ring_8025_vtop(
                    integer32(addr(ring8025_$aux_da.ctl[line].xmit_hdr)));
%endif
  pieces[1].cnt.len := rlen + 22;
  count := 1;
  if pkt.hdr_desc.length <> 0 then begin
%if ring_8025_iomap %then
    pieces[2].pa := ring_8025_vtop(pkt.hdr_desc.address,
                                   pkt.hdr_desc.length,
                                   ring8025_ucb[line].iomap_page);
%else
    pieces[2].pa := ring_8025_vtop(pkt.hdr_desc.address);
%endif
    pieces[2].cnt.len := pkt.hdr_desc.length;
    count := 2;
  end;
  if pkt.data_length <> 0 then begin
    count := count + 1;
%if ring_8025_iomap %then
    pieces[count].pa := ring_8025_map_pa(pkt.data_pages[1],
                                         ring8025_ucb[line].iomap_page + 1);
%else
    pieces[count].pa := pkt.data_pages[1];
%endif
    pieces[count].cnt.len := pkt.data_length;
  end;

  { the frame out }
  ml_$lock(ml_$net_io_lock);
  ring_8025_transmit(addr(ring8025_ucb[line]), total, pieces, count,
                     ring8025_$aux_da.ctl[line].xmit_hdr.dest, fstat, st);
  ml_$unlock(ml_$net_io_lock);
  ml_$exclusion_stop(ring8025_ucb[line].xmit_lock);
  status := st;
end;
