{ ethernet_demux_int - hand a received packet to its socket, at
  interrupt level.

  Image addresses:
    sau6  0x7808A9C4  ethernet_demux_int
    sau7  0x3C494F50  ethernet_demux_int
    sau8  0x03C8874C  ethernet_demux_int
    sau9  0x3C48434C  ethernet_demux_int

  Assume the packet is in the unit's header and data pages, its source
  and type in rcv_src.

  - ethernet_demux at interrupt level, under IPL 7 for the queueing: a
    Domain packet goes to NET_IO (dropped unless the unit takes Domain
    packets); another to the socket of the open channel that owns its
    type, the socket's eventcount advanced without a dispatch.
  - The result is false when the packet must be seen at process level:
    its channel is the system's (MAC_OS_$DEMUX's).
  - A packet no channel takes, or a full socket's, gives its pages
    back; a full socket counts in the eth_stat_not_delivered count.

  Status stored: none.
}

function ethernet_demux_int(u: ethernet_$unit_ptr_t): boolean;
  internal;
label
  drop;
var
  rpkt: mac_os_$rcv_pkt_t;                { ethernet_demux's; not used here }
  info: sock_$pkt_info_t;
  ec: ec_$eventcount_ptr_t;
  sock: pinteger;
  done: boolean;
  handled: boolean;
  old_sr: integer;
  idx: integer;
  i: integer;
begin
  done := true;
  handled := done;
  if u^.rcv_src.ptype = eth_type_domain then begin
    if not (eth_unit_domain in u^.flags) then
      goto drop;
    old_sr := set_sr(16#2700);
    if net_io_$put_in_sock_int(4, u^.cnum, u^.hdr_va, u^.dat_va,
                               u^.rcv_hdr_len, u^.rcv_data_len, ec) then
      ec_$advance_without_dispatch(ec^);
    discard(set_sr(old_sr));
    done := false;
    goto drop;
  end;
  idx := 0;
  for i := 1 to u^.range_count do
    if (u^.rcv_src.ptype >= u^.ranges[i].low)
       and then (u^.rcv_src.ptype <= u^.ranges[i].high) then begin
      idx := i;
      exit;
    end;
  if idx = 0 then
    goto drop;
  with u^.channels[u^.ranges[idx].chan] do begin
    if not open then
      goto drop;
    if socket = eth_os_socket then begin
      done := false;
      handled := done;
      goto drop;
    end;
    sock := socket;
    info.hdr := u^.hdr_va;
    info.data_pages[1] := u^.dat_va;
    info.hdr_len := u^.rcv_hdr_len;
    info.data_len := u^.rcv_data_len;
    info.flags := [];
    info.n_hops := 0;
    time_$abs_clock(info.src_addr);
    old_sr := set_sr(16#2700);
    if sock_$put_int(sock, info, false, 4, u^.cnum, ec) then begin
      ec_$advance_without_dispatch(ec^);
      done := false;
    end
    else
      u^.stats.counts[eth_stat_not_delivered] :=
        u^.stats.counts[eth_stat_not_delivered] + 1;
    discard(set_sr(old_sr));
  end;
drop:
  if done then begin
    netbuf_$rtn_hdr(u^.hdr_va);
    if u^.dat_va <> 0 then
      netbuf_$rtn_dat(u^.dat_va);
  end;
  ethernet_demux_int := handled;
end;
