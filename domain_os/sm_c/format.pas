{ sm_c_$format - format a track of an SM_C drive.

  Image addresses:
    sau5  0x00E751E2  sm_c_$format (module-local)

  Assume we're called with the controller's ML lock held.

  - At most two tries; after the second failure the drive is brought up
    again, the requesting process's pending flag is cleared and the
    status goes into the request.
  - The format table gets sectors 0 through sec_per_track.

  Status stored: none.
}

procedure sm_c_$format(in vol: disk_$volume_t; var req: disk_$io_req_t);
  internal;
var
  i: integer;
  hi_cyl: integer;
  fmt_pa: sm_c_$pa_t;
  hi: sm_$byte_t;
  try: integer;
  status: integer32;
  pvlabel: disk_$pvlabel_info_t;
  flags: pinteger;
begin
  hi_cyl := rshft(req.daddr.cyl, 8);
  for i := 0 to vol.sec_per_track do
    with sm_$cb.c_fmt[i] do begin
      cyl_lo := req.daddr.cyl & 16#FF;
      sec_hi := i div 64;
      cyl_hi := hi_cyl;
      zero_3 := 0;
      head := req.daddr.head;
      zero_2 := 0;
      sec_lo := i mod 64;
    end;

  fmt_pa.all := (integer32(addr(sm_$cb.c_fmt)) & 16#3FF) + sm_c_alloc;
  hi := rshft(fmt_pa.b1, 4);
  for try := 1 to 2 do begin
    sm_$cb.c_op := 12;
    sm_$cb.c_daddr.cyl_lo := req.daddr.cyl & 16#FF;
    sm_$cb.c_daddr.cyl_hi := rshft(req.daddr.cyl, 8);
    sm_$cb.c_daddr.head := req.daddr.head;
    sm_$cb.c_daddr.sector := 0;
    sm_$cb.c_count := vol.sec_per_track;
    sm_$cb.c_buf_hi := hi;
    sm_$cb.c_buf_lo := fmt_pa.b3;
    sm_$cb.c_buf_mid := fmt_pa.b2;
    sm_c_req := nil;
    status := sm_c_$command(vol.dev_unit, sm_c_cmd_format);
    if status = 0 then
      return;
    if try > 1 then
      discard(sm_c_$start_drive(vol.dev_unit, sm_c_dcte, vol.addr_start,
                                vol.sec_per_track, vol.num_heads, pvlabel,
                                flags));
  end;
  disk_bptbl[req.owner_op.owner].io_pending := false;
  req.status.all := status;
end;
