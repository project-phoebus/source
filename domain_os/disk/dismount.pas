{ DISK_$DISMOUNT - dismount a volume and, when it was the last on its
  device, the device's physical volume and its striped members.

  Image addresses:
    sau2  0x00E6CFEA  DISK_$DISMOUNT

  - Under MOUNT_LOCK the volume's buffers are invalidated and a mounted
    or assigned logical volume freed.
  - When no logical volume is left on its driver and unit, the physical
    volume (missing: a crash) has its device shut down and each member
    invalidated and freed.

  Status stored: none.
}

procedure disk_$dismount(vol_idx: integer);
var
  pv: integer;
  refs: integer;
  i: integer;
  k: integer;
  v: integer;
begin
  if vol_idx in [1..10] then begin
    ml_$exclusion_start(mount_lock);
    disk_$invalidate(vol_idx);

    with disk_$dvtbl[vol_idx] do
      if (mount_state = 3) or else (mount_state = 2) then begin
        if lv_start <> 0 then
          mount_state := 0;

        { the volumes on the device }
        pv := 0;
        refs := 0;
        for i := 1 to 10 do
          if ((disk_$dvtbl[i].mount_state = 2) or else
              (disk_$dvtbl[i].mount_state = 3)) and then
             (disk_$dvtbl[i].dev_info = dev_info) and then
             (disk_$dvtbl[i].dev_unit = dev_unit) then
            if disk_$dvtbl[i].lv_start <> 0 then
              refs := refs + 1
            else
              pv := i;

        if refs = 0 then begin
          if pv = 0 then
            crash_system(status_$disk_driver_logic_error);
          disk_$shutdown(disk_$dvtbl[pv].dev_info^, disk_$dvtbl[pv].dev_unit);
          for k := 1 to disk_$dvtbl[pv].num_parts do begin
            v := disk_$dvtbl[pv].part_volx[k];
            disk_$invalidate(v);
            disk_$dvtbl[v].mount_state := 0;
          end;
        end;
      end;

    ml_$exclusion_stop(mount_lock);
  end;
end;
