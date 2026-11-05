{ RING_8025_$SEND - send a Domain packet.

  Image addresses:
    sau7  0x3C49815C  RING_8025_$SEND
    sau8  0x03C8B778  RING_8025_$SEND
    sau9  0x3C48737C  RING_8025_$SEND

  - The driver record's sendp entry.  The packet goes out as the unit's
    MAC header in its control area, an LLC and SNAP header after the
    routing field, the Domain header and the data (from the first data
    page's physical address).
  - A broadcast goes to every station, another packet to its node's
    station address.  With source routing the destination's route is
    found first (ring_8025_find_route) and a routing field marks the
    source address.
  - The transmit is made under the unit's transmit lock; xmit_status is
    always 0.

  Status stored:
    status_$r8025_invalid_unit_num: socket is not unit 0 or 1
    status_$r8025_device_offline: the unit does not take Domain packets
    status_$r8025_illegal_frame_length: the frame, without a routing
      field, is longer than the largest the ring takes
    ring_8025_transmit's status: otherwise
}

procedure ring_8025_$send(var socket: pinteger; hdr_pa: integer32;
                          hdr: pkt_$hdr_ptr_t; hdr_len: integer;
                          in data_pages: univ pkt_$data_pages_t;
                          data_va: integer32; data_len: pinteger;
                          in flags: univ integer;
                          out xmit_status: pinteger;
                          out status_ret: status_$t);
  options(val_param);
var
  count: integer;
  rif_len: integer;
  fstat: integer;
  pieces: array[1..5] of ring_8025_$xmit_piece_t;
  llc: ring_8025_$llc_ptr_t;
  rlen: integer;
  total: integer;
begin
  xmit_status := 0;
  if socket > r8025_max_unit then begin
    status_ret.all := status_$r8025_invalid_unit_num;
    return;
  end;
  if not (r8025_unit_domain in ring8025_ucb[socket].flags) then begin
    status_ret.all := status_$r8025_device_offline;
    return;
  end;

  { the MAC header and the route }
  with ring8025_$aux_da.ctl[socket] do begin
    xmit_hdr.ac := r8025_ac;
    xmit_hdr.fc := r8025_fc_llc;
    if pkt_$hdr_broadcast in hdr^.flag_bits.info_bits then begin
      xmit_hdr.dest.high := 16#FFFFFF;
      xmit_hdr.dest.low := 16#FFFFFF;
    end
    else begin
      xmit_hdr.dest.high := r8025_addr_high;
      xmit_hdr.dest.low := hdr^.dest_node;
    end;
    xmit_hdr.src.high := r8025_addr_high;
    xmit_hdr.src.low := hdr^.src_node;
    if ring8025_ucb[socket].routing then begin
      ring_8025_find_route(addr(ring8025_ucb[socket]),
                           ring8025_$aux_da.ctl[socket].xmit_hdr,
                           r8025_snap_sap, r8025_snap_sap, r8025_llc_ui,
                           rif_len);
      rlen := rif_len;
      if rlen <> 0 then
        xmit_hdr.src.rii := true;
    end
    else
      rlen := 0;
  end;
  total := hdr_len + data_len + 22;
  if total > ring8025_ucb[socket].max_frame then begin
    status_ret.all := status_$r8025_illegal_frame_length;
    return;
  end;
  total := total + rlen;

  { the LLC and SNAP header after the routing field }
  llc := ring_8025_$llc_ptr_t(
           rlen + integer32(addr(ring8025_$aux_da.ctl[socket].xmit_hdr.rif)));
  llc^.dsap := r8025_snap_sap;
  llc^.ssap := r8025_snap_sap;
  llc^.ctl := r8025_llc_ui;
  llc^.snap_org := r8025_snap_org;
  llc^.snap_type := r8025_snap_domain;

  { the pieces: the headers, the Domain header, the data }
  ml_$exclusion_start(ring8025_ucb[socket].xmit_lock);
%if ring_8025_iomap %then
  pieces[1].pa := ring_8025_vtop(
                    integer32(addr(ring8025_$aux_da.ctl[socket].xmit_hdr)),
                    r8025_xmit_hdr_room,
                    ring8025_ucb[socket].iomap_page + r8025_map_ctl);
  pieces[1].cnt.len := rlen + 22;
  pieces[2].pa := ring_8025_map_pa(hdr_pa, ring8025_ucb[socket].iomap_page);
%else
  pieces[1].pa := ring_8025_vtop(
                    integer32(addr(ring8025_$aux_da.ctl[socket].xmit_hdr)));
  pieces[1].cnt.len := rlen + 22;
  pieces[2].pa := hdr_pa;
%endif
  pieces[2].cnt.len := hdr_len;
  count := 2;
  if data_len <> 0 then begin
%if ring_8025_iomap %then
    pieces[3].pa := ring_8025_map_pa(data_pages[1],
                                     ring8025_ucb[socket].iomap_page + 1);
%else
    pieces[3].pa := data_pages[1];
%endif
    pieces[3].cnt.len := data_len;
    count := 3;
  end;
  ring_8025_transmit(addr(ring8025_ucb[socket]), total, pieces, count,
                     ring8025_$aux_da.ctl[socket].xmit_hdr.dest, fstat,
                     status_ret);
  ml_$exclusion_stop(ring8025_ucb[socket].xmit_lock);
end;
