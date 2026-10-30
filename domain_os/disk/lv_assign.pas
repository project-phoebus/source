{ DISK_$LV_ASSIGN - assign a logical volume of a physical volume.

  Image addresses:
    sau2  0x00E6CDB2  DISK_$LV_ASSIGN

  - With the process cleanup bit 5 set and under MOUNT_LOCK, the
    physical volume (marked busy) has its PV label read for the logical
    volume's start, free blocks and size.
  - A free slot (the lowest of 6..1) gets the logical volume, assigned;
    the slot's index is the result.
  - The result and blocks_avail are assigned only on success.

  Status stored:
    status_$ok: the volume was assigned
    status_$invalid_volume_index: an index outside 1..10
    status_$invalid_logical_volume_index: a number outside 1..10, or a
      start outside the volume
    status_$volume_not_properly_mounted: neither the caller's nor
      mounted
    status_$operation_requires_a_physical_volume: a logical volume
    status_$volume_in_use: a slot already holds it
    status_$volume_table_full: no free slot
    disk_$get_block's status: the label could not be read
}

function disk_$lv_assign(in vol_idx: integer; in lv_idx: pinteger;
                         out blocks_avail: integer32;
                         out status: status_$t): pinteger;
label
  10;
var
  st: status_$t;
  saved_state: pinteger;
  lv_daddr: linteger;
  avail: integer32;
  lv_size: integer32;
  set_buff_cell: status_$t;
  free_slot: integer;
  slot: integer;
  pv_label: disk_$pv_label_ptr_t;
begin
  if not (vol_idx in [1..10]) then begin
    status.all := status_$invalid_volume_index;
    return;
  end;
  if (lv_idx > 10) or else (lv_idx = 0) then begin
    status.all := status_$invalid_logical_volume_index;
    return;
  end;

  proc2_$set_cleanup(5);
  ml_$exclusion_start(mount_lock);

  with disk_$dvtbl[vol_idx] do begin
    saved_state := mount_state;
    if not (((saved_state = 2) and (mount_proc = proc1_$current)) or
            (saved_state = 3)) then begin
      st.all := status_$volume_not_properly_mounted;
      goto 10;
    end;
    if lv_start <> 0 then begin
      st.all := status_$operation_requires_a_physical_volume;
      goto 10;
    end;
    mount_state := 3;

    pv_label := disk_$get_block(vol_idx, 0, pv_label_$uid, 0, 0, 0, st);
    if st.all <> status_$ok then
      goto 10;
    lv_daddr := pv_label^.lv_daddr[lv_idx];
    avail := pv_label^.alt_lv_daddr[lv_idx];
    if avail <> 0 then
      avail := avail - lv_daddr;
    if (lv_idx < 10) and then (pv_label^.lv_daddr[lv_idx + 1] <> 0) then
      lv_size := pv_label^.lv_daddr[lv_idx + 1] - lv_daddr
    else
      lv_size := addr_start - lv_daddr;
    disk_$set_buff(pv_label, 12, set_buff_cell);

    if (lv_daddr = 0) or else (lv_daddr > addr_start) then begin
      st.all := status_$invalid_logical_volume_index;
      goto 10;
    end;

    free_slot := 0;
    for slot := 6 downto 1 do
      if disk_$dvtbl[slot].mount_state = 0 then
        free_slot := slot
      else if (dev_unit = disk_$dvtbl[slot].dev_unit) and then
              (lv_daddr = disk_$dvtbl[slot].lv_start) and then
              (dev_info = disk_$dvtbl[slot].dev_info) then begin
        st.all := status_$volume_in_use;
        goto 10;
      end;

    if free_slot = 0 then begin
      st.all := status_$volume_table_full;
      goto 10;
    end;
    disk_$dvtbl[free_slot] := disk_$dvtbl[vol_idx];
    disk_$dvtbl[free_slot].lv_start := lv_daddr;
    disk_$dvtbl[free_slot].addr_start := lv_size;
    disk_$dvtbl[free_slot].mount_proc := proc1_$current;
    disk_$dvtbl[free_slot].as_options := [];
    disk_$dvtbl[free_slot].mount_state := 2;
    disk_$lv_assign := free_slot;
  end;

10:
  disk_$dvtbl[vol_idx].mount_state := saved_state;
  ml_$exclusion_stop(mount_lock);
  blocks_avail := avail;
  status := st;
end;
