{ DISK_$PV_ASSIGN_N - assign a physical volume (the flags form).

  Image addresses:
    sau2  0x00E6C852  DISK_$PV_ASSIGN_N

  - disk_$pv_mount_internal does the work: flag 4 asks for the geometry,
    flag 1 picks mount type 0 (else 1).  The unit id it filled goes back,
    the label record under flag 2 and the geometry under flag 4.
  - vol is not set when the mount fails before the dinit.

  Status stored:
    disk_$pv_mount_internal's status: the unit type is 0, 1 or 4
    status_$invalid_unit_number: any other
}

procedure disk_$pv_assign_n(unit_type: integer; device: integer;
                            unit: integer; flags: integer;
                            out vol_idx: pinteger;
                            var num_blocks: integer32;
                            var sec_per_track: pinteger;
                            var num_heads: pinteger;
                            var pvlabel_info: disk_$pvlabel_buf_t;
                            out status: status_$t);
var
  pv_label: disk_$pvlabel_buf_t;
  local_status: status_$t;
  nb: integer32;
  vol: pinteger;
  mount_type: integer;
  spt: pinteger;
  heads: pinteger;
begin
  nb := num_blocks;
  spt := sec_per_track;
  heads := num_heads;
  pv_label := pvlabel_info;

  if (unit_type <> 0) and then (unit_type <> 1) and then
     (unit_type <> 4) then begin
    status.all := status_$invalid_unit_number;
    return;
  end;

  if (flags & 4) <> 0 then
    nb := -1;
  if (flags & 1) <> 0 then
    mount_type := 0
  else
    mount_type := 1;

  discard(disk_$pv_mount_internal(mount_type, unit_type, device, unit, vol,
                                  nb, spt, heads, pv_label, local_status));
  status := local_status;
  vol_idx := vol;

  if (flags & 2) <> 0 then
    pvlabel_info := pv_label;
  if (flags & 4) <> 0 then begin
    num_blocks := nb;
    sec_per_track := spt;
    num_heads := heads;
  end;
end;
