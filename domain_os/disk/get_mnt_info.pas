{ DISK_$GET_MNT_INFO - describe a mounted or assigned volume.

  Image addresses:
    sau2  0x00E6BE4A  DISK_$GET_MNT_INFO

  - Under MOUNT_LOCK a logical volume is flagged and replaced by its
    physical volume (its own start address given first).
  - The physical volume's end, device type, unit, geometry, sectors per
    block, members and striping are given, the partition words built
    from the members.

  Status stored:
    status_$ok: the volume was described
    status_$invalid_volume_index: an index outside 1..10
    status_$volume_not_properly_mounted: neither mounted nor assigned
}

procedure disk_$get_mnt_info(vol_idx: integer; in param_2: integer;
                             var info: disk_$mnt_info_t;
                             out status: status_$t);
var
  k: integer;
begin
  if not (vol_idx in [1..10]) then begin
    status.all := status_$invalid_volume_index;
    return;
  end;

  ml_$exclusion_start(mount_lock);

  with disk_$dvtbl[vol_idx] do
    if (mount_state <> 3) and then (mount_state <> 2) then
      status.all := status_$volume_not_properly_mounted
    else begin
      if lv_start <> 0 then begin
        info.flags.logical := true;
        vol_idx := part_volx[1];
      end
      else
        info.flags.logical := false;
      info.vol_start := addr_start;

      with disk_$dvtbl[vol_idx] do begin
        status.all := status_$ok;
        info.vol_end := addr_end;
        info.dev_type := dev_info^.device_type;
        info.unit_id := unit_id;
        info.bat_step := bat_step;
        info.sectors_per_track := sec_per_track;
        info.heads := num_heads;

        case sector_size_code of
          0: info.sectors_per_block := 1;
          1: info.sectors_per_block := 2;
          2: info.sectors_per_block := 4;
        end;

        info.n_partitions := num_parts;
        info.interleave := part_volx[0];

        for k := 1 to 8 do
          info.part_info[k].all := 0;

        for k := 1 to num_parts do begin
          info.part_info[k].dev_type := dev_info^.device_type;
          info.part_info[k].ctrl :=
            disk_$dvtbl[part_volx[k]].dev_info^.controller;
          info.part_info[k].unit := disk_$dvtbl[part_volx[k]].dev_unit;
        end;

        info.flags.mounted := mount_state = 3;
        info.flags.dev_not_neg := (dev_info^.unit_count & 16#8000) = 0;
        info.flags.write_protected := 0 in as_options;
        info.flags.dev_bit_13 := (dev_info^.unit_count & 16#2000) <> 0;
        info.flags.dev_bit_11 := (dev_info^.unit_count & 16#800) <> 0;
        info.flags.dev_bit_9 := (dev_info^.unit_count & 16#200) <> 0;
        info.flags.unused_8_0 := 0;
      end;
    end;

  ml_$exclusion_stop(mount_lock);
end;
