{ DISK_IO - one block's transfer, read, write or format.

  Image addresses:
    sau2  0x00E3D50E  DISK_IO

  - One queue block gets the caller's header and disk address, is mapped
    onto the physical volume and goes to the driver (DISK_$DO_IO); a
    write is stamped with the time and the page's checksum.
  - A failure goes to disk_$io_error, three of its outcomes counting as
    success.
  - A checked read compares the header (and, checksumming, the page's
    checksum: a mismatch crashes); a checksummed write is read back.
  - The `case' on op has no otherwise; with no mapped volume io_volx
    keeps op's value.

  Returns:
    status_$ok: the block was transferred
    status_$invalid_volume_index: the index check failed
    status_$disk_write_protected: a write to a protected volume
    the request's status: the driver's, disk_$map_request's, or
      status_$disk_block_header_error (a header mismatch),
      status_$read_after_write_failed or
      status_$checksum_error_in_read_after_write

  Status stored (in the request):
    the same as the result, but the first two
}

function disk_io(op: integer; vol_idx: pinteger; ppn: integer32;
                 daddr: linteger; var info: univ disk_$block_hdr_t): integer32;
label
  10, 20, 30, 40;
var
  map: disk_$vol_map_t;
  verify_info: disk_$block_hdr_t;
  err_wait: integer32;
  io_wait: integer32;
  verify_status: integer32;
  req_tail: disk_$io_req_ptr_t;
  req_head: disk_$io_req_ptr_t;
  result: integer32;
  log_kind: integer;
  sector_w: integer;
  head_w: integer;
  lock_held: boolean;
  queued: boolean;
  raw: boolean;
  dev: disk_$device_entry_ptr_t;
  req: disk_$io_req_ptr_t;
  internal_op: pinteger;
  hdr_check: boolean;
  chk: boolean;
  io_volx: pinteger;
  i: integer;
begin
  lock_held := false;
  if vol_idx > 10 then begin
    result := status_$invalid_volume_index;
    goto 10;
  end;

  for i := 1 to 10 do
    map[i].head := nil;
  dev := disk_$dvtbl[vol_idx].dev_info;

  case op of
    disk_$io_read, disk_$io_read_no_check: begin
      internal_op := disk_$req_op_read;
    end;
    disk_$io_write, disk_$io_write_raw: begin
      internal_op := disk_$req_op_write;
      if 0 in disk_$dvtbl[vol_idx].as_options then begin
        result := status_$disk_write_protected;
        goto 10;
      end;
    end;
    disk_$io_read_badspots: begin
      internal_op := disk_$req_op_format;
    end;
  end;

  raw := ((op = disk_$io_write) and (2 in disk_$dvtbl[vol_idx].as_options))
         or (op = disk_$io_write_raw);
  hdr_check := ((dev^.unit_count & 16#8000) = 0)
               and (op <> disk_$io_read_no_check)
               and (op <> disk_$io_read_badspots);
  chk := ((dev^.unit_count & 16#4000) <> 0) and hdr_check;

  disk_$get_qblks_internal(1, true, req_head, req_tail);
  req := req_head;
  req^.header := info;
  req^.daddr.daddr := daddr;
  disk_$map_request(req, vol_idx, internal_op, map, req^.status);
  if req^.status.all <> status_$ok then
    goto 20;

  { a format's head }
  if op = disk_$io_read_badspots then begin
    req^.daddr.head := daddr;
    req^.daddr.sector := 0;
    req^.daddr.cyl := 0;
  end;

  { the first mapped volume }
  for i := 1 to 10 do
    if map[i].head <> nil then begin
      io_volx := i;
      exit;
    end;

  req^.ppn := ppn;
  req^.owner_op.chksum := 1 in disk_$dvtbl[vol_idx].as_options;
  if chk then begin
    ml_$exclusion_start(disk_$exclusion_2);
    lock_held := true;
  end;

  { a write's stamp }
  if (internal_op = disk_$req_op_write) and then
     ((dev^.unit_count & 16#8000) = 0) and then not raw then begin
    req^.header.written := time_$clockh;
    req^.header.unused_12 := 0;
    req^.header.unused_16 := 0;
    if chk then
      req^.header.chksum := chksum(req^.ppn)
    else
      req^.header.chksum := 0;
  end;

  if internal_op = disk_$req_op_read then
    req^.header.hint := ~req^.header.hint;
  mmu_$mcr_change(6);
  io_wait := disk_bptbl[proc1_$current].io_ec.value + 1;
  err_wait := disk_bptbl[proc1_$current].err_ec.value + 1;

  disk_$do_io(disk_$dvtbl[io_volx], req^, req^, queued);
  if queued then
    disk_$wait_io([io_volx], io_wait, err_wait);

  { a failure }
  if req^.status.all <> status_$ok then begin
    if req^.status.all = status_$disk_write_protected then begin
      disk_$dvtbl[vol_idx].as_options := disk_$dvtbl[vol_idx].as_options + [0];
      goto 20;
    end;
    disk_$io_error(io_volx, req^, info.l);
    if not ((req^.status.all = status_$disk_ok_after_device_recovery) or else
            (req^.status.all = status_$disk_ok_after_retry) or else
            (req^.status.all = status_$disk_ok_after_crc_correction)) then
      goto 20;
    req^.status.all := status_$ok;
  end;

  if hdr_check and then (internal_op = disk_$req_op_read) then begin
    { a read's header and checksum }
    if (info.uid <> req^.header.uid) or else
       (info.hint <> req^.header.hint) then begin
      req^.status.all := status_$disk_block_header_error;
      disk_$io_error(io_volx, req^, info.l);
      goto 20;
    end;
    if chk then
      if (chksum(req^.ppn) <> req^.header.chksum) and
         (req^.header.chksum <> 0) then begin
        verify_status := status_$ok;
        req^.status.all := status_$software_detected_checksum_error;
        goto 30;
      end;
  end
  else if ((internal_op = disk_$req_op_write) and chk) and then
          (disk_$raw_ppn <> 0) then begin
    { a checksummed write read back }
    verify_status := disk_io(disk_$io_read_no_check, vol_idx, disk_$raw_ppn,
                             daddr, verify_info);
    if (verify_status <> status_$ok) or else
       (verify_info.l <> req^.header.l) then begin
      req^.status.all := status_$read_after_write_failed;
      goto 30;
    end;
    if chksum(disk_$raw_ppn) <> req^.header.chksum then begin
      req^.status.all := status_$checksum_error_in_read_after_write;
      goto 30;
    end;
  end;
  goto 40;

30:
  crash_system(req^.status);
  goto 20;

  { the log }
40:
  if netlog_$ok_to_log then begin
    if internal_op = disk_$req_op_read then
      log_kind := 6
    else
      log_kind := 7;
    if (dev^.unit_count & 16#200) <> 0 then
      netlog_$log_it(log_kind, req^.header.uid, 0, 0, req^.ppn, 0, 0, 0)
    else begin
      head_w := req^.daddr.head;
      sector_w := req^.daddr.sector;
      netlog_$log_it(log_kind, req^.header.uid, rshft(req^.header.hint, 5),
                     req^.header.hint & 16#1F, req^.ppn, req^.daddr.cyl,
                     head_w, sector_w);
    end;
  end;

20:
  if lock_held then
    ml_$exclusion_stop(disk_$exclusion_2);
  if internal_op = disk_$req_op_read then
    info := req^.header;
  result := req^.status.all;
  disk_$rtn_qblks_internal(1, req, req_tail);

10:
  disk_io := result;
end;
