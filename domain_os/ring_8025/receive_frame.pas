{ ring_8025_receive_frame - deliver the frame of the unit's current receive
  list.

  Image addresses:
    sau7  0x3C49771C  copy_data (nested)
    sau8  0x03C8AD3C  copy_data (nested)
    sau9  0x3C486940  copy_data (nested)
    sau7  0x3C497804  ring_8025_receive_frame
    sau8  0x03C8AE24  ring_8025_receive_frame
    sau9  0x3C486A28  ring_8025_receive_frame

  - A frame with a routing field of an odd length, shorter than 2 or
    longer than 30 bytes, one too short for its routing field and LLC
    header, or one longer than 4504 bytes is dropped.
  - A Domain packet goes to NET_IO_$PUT_IN_SOCK while the unit is
    started for the network, unless its header is longer than 952
    bytes, its data than a page, or it comes from this node.
  - An XID or TEST to the null SAP is queued for its answer.  An XID's
    answer to the driver's SAP teaches the station's route, or that it
    is on this ring, when the unit uses source routing.
  - Every other frame goes to the open channel whose range holds its
    type: through MAC_OS_$DEMUX for a channel the system opened, else to
    its socket.  The first 952 bytes go to a header page, the routing
    field left out when the channel asks for that; the rest to data
    pages, given back when the frame is not taken.

  Status stored: none.
}

procedure ring_8025_receive_frame(u: ring_8025_$unit_ptr_t);
  internal;
var
  rpkt: mac_os_$rcv_pkt_t;
  info: sock_$pkt_info_t;
  pages: pkt_$data_pages_t;
  status: status_$t;
  fp: ring_8025_$mac_hdr_ptr_t;
  llc: ring_8025_$llc_ptr_t;
  hdr_pa: integer32;
  hdr_va: integer32;
  t: ring_8025_$ftype_t;
  dst: integer32;
  src: integer32;
  h: integer32;
  len: pinteger;
  off: pinteger;
  chunk: pinteger;
  rest: pinteger;
  rif_len: integer;
  npages: integer;
  i: integer;
  n: pinteger;
  dlen: pinteger;
  hlen: pinteger;
  node: linteger;
  demux_flag: boolean;
  ctl: integer;
  dsap: integer;
  r: integer;
  sock: pinteger;

  { copy_data - copy the frame's dlen bytes from off into data pages,
    a page at a time through the unit's second window; npages returns
    the pages taken, and the pages not taken are cleared. }
  procedure copy_data;
  begin
    rest := dlen;
    npages := 0;
    while rest <> 0 do begin
      npages := npages + 1;
      netbuf_$get_dat(pages[npages]);
      chunk := min(rest, 1024);
      src := off + integer32(fp);
      mmu_$set_pmape(u^.win2_va, u^.win2_pmape, rshft(pages[npages], 10));
      os_$data_copy(pkt_$bytes_ptr_t(src)^,
                    pkt_$bytes_ptr_t(u^.win2_va)^, chunk);
      off := off + chunk;
      rest := rest - chunk;
    end;
    for i := npages + 1 to 4 do
      pages[i] := 0;
  end;

begin
  mmu_$mcr_change(4);
  u^.stats.rcv_frames := u^.stats.rcv_frames + 1;
  pages[1] := 0;
  rif_len := 0;

  { the frame, its routing field and LLC header }
  fp := u^.rcv_list^.buf;
  if fp^.src.rii then begin
    rif_len := fp^.rif.rc.len;
    if rif_len mod 2 <> 0 then
      return;
    if rif_len < 2 then
      return;
    if rif_len > 30 then
      return;
  end;
  llc := ring_8025_$llc_ptr_t(rif_len + integer32(addr(fp^.rif)));
  len := u^.rcv_list^.frame_size;
  if len < rif_len + 20 then
    return;
  if len > r8025_frame_size then
    return;
  t.zero := 0;
  t.sap := llc^.dsap;
  t.snap := llc^.snap_type;

  { a Domain packet }
  if t.all = r8025_type_domain then begin
    hlen := llc^.pkt.total_len;
    dlen := llc^.pkt.pkt_data_len;
    node := llc^.pkt.src_node;
    if hlen > r8025_hdr_max then
      return;
    if dlen > 1024 then
      return;
    if not (r8025_unit_domain in u^.flags) then
      return;
    if node = node_$me then
      return;
    netbuf_$get_hdr(hdr_pa, hdr_va);
    src := integer32(llc) + 8;
    os_$data_copy(pkt_$bytes_ptr_t(src)^, pkt_$bytes_ptr_t(hdr_va)^, hlen);
    if dlen <> 0 then begin
      src := integer32(llc) + hlen + 8;
      netbuf_$get_dat(pages[1]);
      mmu_$set_pmape(u^.win2_va, u^.win2_pmape, rshft(pages[1], 10));
      os_$data_copy(pkt_$bytes_ptr_t(src)^, pkt_$bytes_ptr_t(u^.win2_va)^,
                    dlen);
    end;
    net_io_$put_in_sock(5, u^.cnum, hdr_va, pages, hlen, dlen);
    return;
  end;

  { an XID or TEST: to the null SAP, queued; an XID's answer, learned }
  ctl := llc^.ctl;
  if ((ctl & r8025_llc_xid) = r8025_llc_xid) or else
     ((ctl & r8025_llc_test) = r8025_llc_test) then begin
    dsap := llc^.dsap;
    if dsap = r8025_null_sap then begin
      netbuf_$get_hdr(hdr_pa, hdr_va);
      n := min(r8025_hdr_max, len);
      os_$data_copy(fp^, pkt_$bytes_ptr_t(hdr_va)^, n);
      dlen := len - n;
      if dlen <> 0 then begin
        off := n;
        copy_data;
      end;
      ring_8025_queue_nullsap(u, hdr_va, hdr_pa, n, pages, dlen);
      return;
    end;

    { an XID to the driver's SAP from the null SAP: the source SAP's
      bits 1..7 clear, its response bit either way }
    if ((ctl & r8025_llc_test) <> r8025_llc_test) and then
       ((dsap = r8025_xid_ssap) and u^.routing) and then
       ((llc^.ssap ! ~16#FE) = ~16#FE) then
      if rif_len <> 0 then begin
        if not fp^.dest.group then
          ring_8025_learn_route(u, fp^);
      end
      else
        ring_8025_learn_local(u, fp^.src);
  end;

  { the channel whose range holds the type }
  r := ring_8025_find_type(t.all, u^.ranges, u^.range_count);
  if r = 0 then
    return;
  if not u^.channels[u^.ranges[r].chan].open then
    return;
  netbuf_$get_hdr(hdr_pa, hdr_va);
  h := hdr_va;
  if u^.channels[u^.ranges[r].chan].strip_rif then begin
    fp^.src.rii := false;
    len := len - rif_len;
    os_$data_copy(fp^, pkt_$bytes_ptr_t(h)^, 14);
    dst := h + 14;
%if ring_8025_rif_sum_reversed %then
    src := integer32(fp) + rif_len + 14;
%else
    src := integer32(fp) + 14 + rif_len;
%endif
    n := min(r8025_hdr_max, len);
    os_$data_copy(pkt_$bytes_ptr_t(src)^, pkt_$bytes_ptr_t(dst)^, n - 14);
    dlen := len - n;
    if dlen <> 0 then begin
      off := rif_len + n;
      copy_data;
    end;
  end
  else begin
    n := min(r8025_hdr_max, len);
    os_$data_copy(fp^, pkt_$bytes_ptr_t(h)^, n);
    dlen := len - n;
    if dlen <> 0 then begin
      off := n;
      copy_data;
    end;
  end;

  sock := u^.channels[u^.ranges[r].chan].socket;
  if sock = r8025_os_socket then begin

    { a channel the system opened }
    rpkt.is_local := (fp^.dest.high = 16#FFFFFF)
                     and then (fp^.dest.low = 16#FFFFFF);
    rpkt.link_addr.n_words := 3;
    for i := 0 to 2 do
      rpkt.link_addr.addr[i] := fp^.src.words[i];
    rpkt.frame_type := 0;
    rpkt.frame_type := t.snap;
    rpkt.data_pa := pages;
    rpkt.body_len := n - 22;
    rpkt.body := h + 22;
    rpkt.unused_24 := 0;
    rpkt.data_len := dlen;
    demux_flag := false;
    mac_os_$demux(rpkt, u^.port, demux_flag, status);
    if status.all = status_$ok then
      return;
    netbuf_$rtn_hdr(hdr_va);
    if dlen <> 0 then
      for i := 1 to npages do
        netbuf_$rtn_dat(pages[i]);
  end
  else begin

    { a user channel's socket }
    info.hdr := h;
    info.data_pages := pages;
    info.hdr_len := n;
    info.data_len := dlen;
    info.flags := [];
    info.n_hops := 0;
    time_$abs_clock(info.src_addr);
    if sock_$put(sock, info, false, 5, u^.cnum) then
      return;
    u^.stats.rcv_refused := u^.stats.rcv_refused + 1;
    netbuf_$rtn_hdr(hdr_va);
    if dlen <> 0 then
      for i := 1 to npages do
        netbuf_$rtn_dat(pages[i]);
  end;
end;
