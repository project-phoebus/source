{ sm_c_$start_drive - bring an SM_C drive up and read its id.

  Image addresses:
    sau5  0x00E74D96  sm_c_$start_drive (module-local)

  Assume we're called with the controller's ML lock held.

  - The start is tried at most four times; a drive not ready gets two
    clock ticks and the restore command again.
  - The unit is marked ready when the drive starts.
  - flags is set to 1; dcte and the other geometry are not read.

  Returns:
    status_$unrecognized_drive_id: the block count is not positive, or
      the id's top three bits are not all set
    the commands' status: otherwise (0 when the drive starts)

  Status stored: none.
}

function sm_c_$start_drive(unit: integer; dcte: dcte_ptr_t;
                           in num_blocks: univ integer32;
                           in sec_per_track: pinteger;
                           in num_heads: pinteger;
                           out pvlabel_info: univ disk_$pvlabel_info_t;
                           out flags: pinteger): integer32; internal;
var
  status: integer32;
  id_status: integer32;
  try: integer;
begin
  flags := 1;
  if num_blocks <= 0 then begin
    sm_c_$start_drive := status_$unrecognized_drive_id;
    return;
  end;

  sm_c_req := nil;
  sm_$cb.c_daddr.cyl_lo := 16#FF;
  sm_$cb.c_daddr.cyl_hi := 7;
  sm_$cb.c_daddr.hs := sm_$cb.c_daddr.hs ! 16#FFFF;
  for try := 1 to 4 do begin
    status := sm_c_$command(unit, sm_c_cmd_start);
    if status = 0 then
      status := sm_c_$command(unit, sm_c_cmd_restore);
    if status = status_$disk_not_ready then begin
      discard(ec_$wait(addr(time_$clockh_ec), addr(ec_$nil_ec),
                       addr(ec_$nil_ec), time_$clockh + 2, 0, 0));
      status := sm_c_$command(unit, sm_c_cmd_restore);
    end;
    if status = 0 then
      exit;
  end;

  sm_$cb.c_daddr.all := 0;
  id_status := sm_c_$command(unit, sm_c_cmd_read_id);
  if id_status = 0 then
    if (sm_$cb.c_id & 16#E0) <> 16#E0 then
      id_status := status_$unrecognized_drive_id;
  sm_$cb.c_id := 0;
  sm_$cb.c_b0e := 0;
  sm_$cb.c_b10 := 0;
  sm_c_$start_drive := id_status;
  sm_$cb.c_unit[unit].flags.ready := id_status = 0;
end;
