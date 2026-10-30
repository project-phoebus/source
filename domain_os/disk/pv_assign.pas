{ DISK_$PV_ASSIGN - assign a physical volume (the older form).

  Image addresses:
    sau2  0x00E6C95C  DISK_$PV_ASSIGN
    sau9  0x3C473562  DISK_$PV_ASSIGN

  - The fifth argument picks DISK_$PV_ASSIGN_N's flags: above 0 assign
    only (1), 0 also the geometry (5), below 0 also the label record
    (7), whose first six bytes are stored at the address -value.
  - pv_label is not cleared before the mount.

  Status stored:
    disk_$pv_assign_n's status: in either case
}

procedure disk_$pv_assign(unit_type: integer; device: integer;
                          unit: integer; out vol_idx: pinteger;
                          var info: integer32;
                          var sec_per_track: pinteger;
                          var num_heads: pinteger;
                          out status: status_$t);
var
  flags: integer;
  pv_label: disk_$pvlabel_buf_t;
  info_val: integer32;
begin
  info_val := info;
  flags := 1;
  if info_val <= 0 then begin
    flags := 5;
    if info_val < 0 then
      flags := flags ! 2;
  end;

  disk_$pv_assign_n(unit_type, device, unit, flags, vol_idx, info,
                    sec_per_track, num_heads, pv_label, status);

  if info_val < 0 then
    disk_$pvlabel_head_ptr_t(-info_val)^ := pv_label.head;
end;
