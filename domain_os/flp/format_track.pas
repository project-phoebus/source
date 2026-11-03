{ flp_format_track - format the track a request names.

  Image addresses:
    sau2  0x00E3DC78  flp_format_track (module-local)
    sau8  0x03C45C04  flp_format_track (module-local)

  - A failure's status goes into the request, and the requesting
    process's pending flag is cleared.

  Status stored: none.
}

%if floppy_atbus %then
procedure flp_format_track(in vol: disk_$volume_t;
                           var req: disk_$io_req_t); internal;
var
  status: integer32;
  sector: integer;
  unit: integer;
  st: status_$t;
  residue: integer32;
begin
  flp_hw_addr := flp_ctlr_table[vol.dev_info^.controller].hw_addr;

  { the sector IDs }
  for sector := 1 to vol.sec_per_track do
    with flp_io_buffer[sector] do begin
      c := req.daddr.cyl;
      h := req.daddr.head;
      r := sector;
      n := flp_fmt_n;
    end;

  { no retries for a format }
  flp_cmd_retry := 0;

  if (flp_hw_addr^.main_status & 16#1F) <> 0 then
    status := status_$disk_controller_busy
  else begin
    { the IDs out on channel 2 }
    dma_$start_ncheck(2, vol.sec_per_track * 4,
                      (flp_fmt_buf_pa & 16#3FF) ! flp_fmt_buf_pa2, 1, 0, st);
    if st.all <> status_$ok then
      status := st.all
    else begin
      flp_fmt_cmd[1] := req.daddr.head * 4 + vol.dev_unit;
      unit := vol.dev_unit;
      status := status_$ok;
      if flp_unit_cyl[unit] <> req.daddr.cyl then begin
        flp_seek_cmd[1] := flp_fmt_cmd[1];
        flp_seek_cmd[2] := req.daddr.cyl;
        status := excs(flp_seek_cmd, 3, vol);
        flp_unit_cyl[unit] := flp_$sregs[1].w;
      end;
      if status = status_$ok then
        status := excs(flp_fmt_cmd, 6, vol);
      dma_$stop(2, residue, st);
      if status = status_$ok then
        status := st.all;
    end;
  end;

  if status <> status_$ok then begin
    disk_bptbl[req.owner_op.owner].io_pending := false;
    req.status.all := status;
  end;
end;
%else

procedure flp_format_track(in vol: disk_$volume_t;
                           var req: disk_$io_req_t); internal;
var
  status: integer32;
  sector: integer;
  unit: integer;
  unused_10: integer32;                   { stand-in }
  unused_14: integer32;                   { stand-in }
  unused_18: integer32;                   { stand-in }
  unused_1c: integer32;                   { stand-in }
  unused_20: integer32;                   { stand-in }
begin
  flp_hw_addr := flp_ctlr_table[vol.dev_info^.controller].hw_addr;

  { the sector IDs }
  for sector := 1 to vol.sec_per_track do
    with flp_io_buffer[sector] do begin
      c := req.daddr.cyl;
      h := req.daddr.head;
      r := sector;
      n := flp_fmt_n;
    end;

  { no retries for a format }
  flp_cmd_retry := 0;

  if (flp_hw_addr^.main_status & 16#1F) <> 0 then
    status := status_$disk_controller_busy
  else begin
    flp_fmt_cmd[1] := req.daddr.head * 4 + vol.dev_unit;
    unit := vol.dev_unit;
    status := status_$ok;
    if flp_unit_cyl[unit] <> req.daddr.cyl then begin
      flp_seek_cmd[1] := flp_fmt_cmd[1];
      flp_seek_cmd[2] := req.daddr.cyl;
      status := excs(flp_seek_cmd, 3, vol);
      flp_unit_cyl[unit] := flp_$sregs[1].w;
    end;
    if status = status_$ok then begin
      flp_hw_addr^.control := 3;
      dma[3].mtc := vol.sec_per_track * 4 div 2;
      dma[3].mar := flp_fmt_buf_pa;
      dma[3].ocr := chr(16#12);
      dma[3].mfc := chr(1);
      dma[3].ccr := chr(16#80);
      status := excs(flp_fmt_cmd, 6, vol);
    end;
  end;

  if status <> status_$ok then begin
    disk_bptbl[req.owner_op.owner].io_pending := false;
    req.status.all := status;
  end;
end;
%endif
