{ DISK_$FORMAT - format one track of a volume.

  Image addresses:
    sau2  0x00E3D396  DISK_$FORMAT

  - The head is split by the volume's heads per partition into a
    partition and a head within it.
  - One queue block (cylinder, head, sector 1, operation 3) goes to the
    partition volume's driver, and a queued request is waited for.
  - The index tests are set membership, modulo 32; the partition's
    volume is read before the partition is checked.

  Status stored:
    the request's status: the track was formatted, or not
    status_$invalid_volume_index: an index outside 1..10, or a
      partition above 8 or without a volume
    status_$volume_not_properly_mounted: the volume is not the caller's
    status_$disk_illegal_request_for_device: the driver does not format
      tracks (bit 9 of its flags set)
}

procedure disk_$format(in vol_idx: integer; in cyl: integer; in head: pinteger;
                       out status: status_$t);
var
  err_wait: integer32;
  io_wait: integer32;
  tail: disk_$io_req_ptr_t;
  head_blk: disk_$io_req_ptr_t;
  req: disk_$io_req_ptr_t;
  dev: disk_$device_entry_ptr_t;
  part: pinteger;
  hd: pinteger;
  queued: boolean;
  part_vol: pinteger;
begin
  if not (vol_idx in [1..10]) then begin
    status.all := status_$invalid_volume_index;
    return;
  end;

  dev := disk_$dvtbl[vol_idx].dev_info;
  if (disk_$dvtbl[vol_idx].mount_state <> 2) or else
     (disk_$dvtbl[vol_idx].mount_proc <> proc1_$current) then begin
    status.all := status_$volume_not_properly_mounted;
    return;
  end;

  if (dev^.unit_count & 16#200) <> 0 then begin
    status.all := status_$disk_illegal_request_for_device;
    return;
  end;

  disk_$get_qblks_internal(1, false, head_blk, tail);
  req := head_blk;
  io_wait := disk_bptbl[proc1_$current].io_ec.value + 1;
  err_wait := disk_bptbl[proc1_$current].err_ec.value + 1;

  part := head div disk_$dvtbl[vol_idx].num_heads + 1;
  hd := head mod disk_$dvtbl[vol_idx].num_heads;
  part_vol := disk_$dvtbl[vol_idx].part_volx[part];
  if (part > 8) or else not (part_vol in [1..10]) then begin
    status.all := status_$invalid_volume_index;
    return;
  end;

  with req^ do begin
    daddr.cyl := cyl;
    daddr.head := hd;
    daddr.sector := 1;
    owner_op.op := disk_$req_op_format_track;
  end;

  disk_$do_io(disk_$dvtbl[part_vol], req^, req^, queued);
  if queued then
    disk_$wait_io([part_vol], io_wait, err_wait);

  status := req^.status;
  disk_$rtn_qblks_internal(1, req, tail);
end;
