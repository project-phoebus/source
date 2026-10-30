{ DISK_$LV_UID - the UID of a physical volume's logical volume.

  Image addresses:
    sau2  0x00E6CC62  DISK_$LV_UID

  - Under MOUNT_LOCK the mounted physical volume's PV label gives the
    logical volume's block (a stopped storage module tolerated), whose
    label gives the UID.
  - A failure does not set the UID cell.

  Status stored:
    status_$ok: the UID was found
    status_$volume_not_properly_mounted: the volume is not mounted
    status_$operation_requires_a_physical_volume: a logical volume
    status_$invalid_logical_volume_index: a number outside 1..10, or a
      block outside the volume
    disk_$get_block's status: a label could not be read
}

procedure disk_$lv_uid(pv_idx: integer; lv_num: pinteger; out lv_uid: uid_$t;
                       out status: status_$t);
label
  10;
var
  st: status_$t;
  local_uid: uid_$t;
  set_buff_cell: status_$t;
  pv_label: disk_$pv_label_ptr_t;
  lv_label: bat_$label_ptr_t;
  lv_daddr: linteger;
begin
  ml_$exclusion_start(mount_lock);

  with disk_$dvtbl[pv_idx] do begin
    if mount_state <> 3 then begin
      st.all := status_$volume_not_properly_mounted;
      goto 10;
    end;
    if lv_start <> 0 then begin
      st.all := status_$operation_requires_a_physical_volume;
      goto 10;
    end;
    if (lv_num = 0) or else (lv_num > 10) then begin
      st.all := status_$invalid_logical_volume_index;
      goto 10;
    end;

    pv_label := disk_$get_block(pv_idx, 0, pv_label_$uid, 0, 0, 16#20, st);
    if (st.all <> status_$ok) and then
       (st.all <> status_$storage_module_stopped) then
      goto 10;
    lv_daddr := pv_label^.lv_daddr[lv_num];
    disk_$set_buff(pv_label, 8, set_buff_cell);

    if (lv_daddr = 0) or else (lv_daddr > addr_start) then begin
      st.all := status_$invalid_logical_volume_index;
      goto 10;
    end;

    lv_label := disk_$get_block(pv_idx, lv_daddr, lv_label_$uid, 0, 0, 16#20,
                                st);
    if (st.all <> status_$ok) and then
       (st.all <> status_$storage_module_stopped) then
      goto 10;
    local_uid := lv_label^.lv_uid;
    disk_$set_buff(lv_label, 12, set_buff_cell);
  end;

10:
  ml_$exclusion_stop(mount_lock);
  lv_uid := local_uid;
  status := st;
end;
