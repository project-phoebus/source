{ DISK_$LV_MOUNT - mount a logical volume by its UID.

  Image addresses:
    sau2  0x00E6CA3A  DISK_$LV_MOUNT

  - Under MOUNT_LOCK a free slot is found (the lowest of 6..1).
  - Each mounted physical volume's PV label and logical-volume labels
    are read; the one with the UID (version 1 or below) gets the slot,
    mounted.  The slot's index is the result.

  Status stored:
    status_$ok: the volume was mounted
    status_$disk_already_mounted: it is (its index returned)
    status_$volume_table_full: no free slot
    status_$logical_volume_not_found: no label has the UID
    disk_$get_block's status: a label could not be read
}

function disk_$lv_mount(lv_uid: uid_$t; out status: status_$t): integer;
label
  10;
var
  st: status_$t;
  buf_status: status_$t;
  lv_block_table: disk_$lv_daddr_list_t;
  free_slot: integer;
  i: integer;
  pv_idx: integer;
  j: integer;
  lv_block: linteger;
  pv_label: disk_$pv_label_ptr_t;
  lv_label: bat_$label_ptr_t;
begin
  ml_$exclusion_start(mount_lock);

  { a free slot, or the volume already mounted }
  free_slot := 0;
  for i := 6 downto 1 do
    if disk_$dvtbl[i].mount_state = 0 then
      free_slot := i
    else if (disk_$dvtbl[i].mount_state = 3) and then
            (disk_$dvtbl[i].lv_uid = lv_uid) then begin
      free_slot := i;
      st.all := status_$disk_already_mounted;
      goto 10;
    end;

  if free_slot = 0 then begin
    st.all := status_$volume_table_full;
    goto 10;
  end;

  { the mounted physical volumes }
  for pv_idx := 10 downto 1 do
    if (disk_$dvtbl[pv_idx].mount_state = 3) and then
       (disk_$dvtbl[pv_idx].lv_start = 0) then begin
      pv_label := disk_$get_block(pv_idx, 0, pv_label_$uid, 0, 0, 0, st);
      if st.all <> status_$ok then
        goto 10;
      lv_block_table := pv_label^.lv_daddr;
      disk_$set_buff(pv_label, 8, buf_status);

      for j := 1 to 10 do begin
        lv_block := lv_block_table[j];
        if lv_block = 0 then
          exit;
        lv_label := disk_$get_block(pv_idx, lv_block, lv_label_$uid, 0, 0, 0,
                                    st);
        if st.all <> status_$ok then
          goto 10;
        if (lv_label^.version <= 1) and then
           (lv_label^.lv_uid = lv_uid) then begin
          disk_$dvtbl[free_slot] := disk_$dvtbl[pv_idx];
          disk_$dvtbl[free_slot].lv_start := lv_block;
          disk_$dvtbl[free_slot].addr_start :=
            lv_label^.bat_hdr.first_data_block + lv_label^.bat_hdr.total_blocks;
          disk_$dvtbl[free_slot].lv_uid := lv_uid;
          disk_$dvtbl[free_slot].as_options := [];
          disk_$dvtbl[free_slot].mount_state := 3;
          disk_$dvtbl[free_slot].bat_step := lv_label^.bat_hdr.bat_step;
          disk_$dvtbl[pv_idx].bat_step := disk_$dvtbl[free_slot].bat_step;
          disk_$set_buff(lv_label, 12, buf_status);
          goto 10;
        end;
        disk_$set_buff(lv_label, 12, buf_status);
      end;
    end;

  st.all := status_$logical_volume_not_found;

10:
  ml_$exclusion_stop(mount_lock);
  status := st;
  disk_$lv_mount := free_slot;
end;
