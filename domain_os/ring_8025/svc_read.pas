{ RING_8025_$SVC_READ - receive a frame on a user channel.

  Image addresses:
    sau8  0x03C8BF78  RING_8025_$SVC_READ
    sau9  0x3C487B7C  RING_8025_$SVC_READ

  - The driver record's svc_read entry.  Under a cleanup handler the
    next frame is taken off the channel's socket and its header page and
    data pages scattered into the caller's vector, each data page
    through the unit's first window page; len_out is the frame's length.
    The pages go back as they are copied, and on a fault the header page
    if one was taken and every data page still held.
  - A frame longer than the vector's room is dropped.

  Status stored:
    status_$ok: a frame was received
    status_$r8025_invalid_unit_num: unit is not 0 or 1
    status_$r8025_device_offline: the unit is not on line
    status_$r8025_channel_not_open: channel is 0, above 10 or not open
    status_$r8025_no_frame_to_receive: the socket holds no frame
    status_$r8025_rcv_buffer_too_small: the frame is longer than the
      vector's room
    fim_$cleanup's status: a fault
}

procedure ring_8025_$svc_read(var unit: pinteger; var channel: pinteger;
                              unused3: integer; var unused4: univ integer32;
                              var iov: univ ring_8025_$iov_array_t;
                              iov_cnt: integer; out len_out: pinteger;
                              out status: status_$t);
  options(val_param);
var
  info: sock_$pkt_info_t;
  crec: fim_$cleanup_rec_t;
  data_pa: pkt_$data_pages_t;
  cleanup_status: status_$t;
  hdr_va: integer32;
  off: integer;
  idx: integer;
  page: integer;
  room: integer;
  u: ring_8025_$unit_ptr_t;
  hdr_len: integer;
  data_len: integer;
  n: integer;
  k: integer;
begin
  if unit > r8025_max_unit then begin
    status.all := status_$r8025_invalid_unit_num;
    return;
  end;
  hdr_va := 0;
  page := 0;
  room := 0;

  cleanup_status := fim_$cleanup(crec);
  if cleanup_status.all = fault_$cleanup_set then begin
    { the unit, the channel }
    u := addr(ring8025_ucb[unit]);
    if not (r8025_unit_online in u^.flags) then begin
      fim_$rls_cleanup(crec);
      status.all := status_$r8025_device_offline;
      return;
    end;
    if (channel = 0) or else (channel > r8025_max_chan)
       or else not u^.channels[channel].open then begin
      fim_$rls_cleanup(crec);
      status.all := status_$r8025_channel_not_open;
      return;
    end;

    { a frame }
    if not sock_$get(u^.channels[channel].socket, info) then begin
      fim_$rls_cleanup(crec);
      status.all := status_$r8025_no_frame_to_receive;
      return;
    end;
    hdr_va := info.hdr;
    hdr_len := info.hdr_len;
    data_len := info.data_len;
    data_pa := info.data_pages;
    len_out := hdr_len + data_len;
    for k := 1 to iov_cnt do
      room := room + iov[k].len;
    if room < len_out then begin
      netbuf_$rtn_hdr(hdr_va);
      pkt_$dump_data(data_pa, data_len);
      fim_$rls_cleanup(crec);
      status.all := status_$r8025_rcv_buffer_too_small;
      return;
    end;

    { the header page }
    idx := 1;
    off := 0;
    ring_8025_copy_to_user(hdr_va, hdr_len, iov, iov_cnt, idx, off);
    netbuf_$rtn_hdr(hdr_va);

    { the data pages }
    while data_len <> 0 do begin
      page := page + 1;
      mmu_$set_pmape(u^.win1_va, u^.win1_pmape, rshft(data_pa[page], 10));
      n := data_len;
      if n > 1024 then
        n := 1024;
      ring_8025_copy_to_user(u^.win1_va, n, iov, iov_cnt, idx, off);
      netbuf_$rtn_dat(data_pa[page]);
      data_pa[page] := 0;
      data_len := data_len - n;
    end;

    fim_$rls_cleanup(crec);
    status.all := status_$ok;
  end

  else begin
    { a fault }
    if hdr_va <> 0 then
      netbuf_$rtn_hdr(hdr_va);
    for page := 1 to 4 do
      if data_pa[page] <> 0 then
        netbuf_$rtn_dat(data_pa[page]);
    status := cleanup_status;
  end;
end;
