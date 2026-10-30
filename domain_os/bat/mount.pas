{ BAT_$MOUNT - mount a volume's BAT from its logical-volume label.

  Image addresses:
    sau2  0x00E3B6F8  BAT_$MOUNT

  - Under the BAT lock.  A volume that needs salvaging (the label's
    trouble bit or its salvage word) is refused unless salvage_ok.
  - A mounted volume's label is stamped (the salvage word set until a
    clean dismount) and written back; an old-format volume gets one
    partition of the whole free pool less 11.

  Status stored:
    dbuf_$set_buff's status: the label was written back
    status_$disk_needs_salvaging: the volume needs salvaging
    dbuf_$get_block's status: the label could not be read
}

procedure bat_$mount(vol_idx: integer; salvage_ok: boolean;
                     out status: status_$t);
label
  done;
var
  clockh: time_$clockh_t;
  label_addr: integer32;
  needs_salvage: boolean;
begin
  clockh := time_$current_clockh;
  ml_$lock(ml_$bat_lock);
  bat_$mounted[vol_idx] := false;

  label_addr := integer32(dbuf_$get_block(vol_idx, 0, lv_label_$uid, 0, 0, 0,
                                          status));
  if status.all <> status_$ok then
    goto done;

  with bat_data[vol_idx], bat_$label_ptr_t(label_addr)^ do begin
    bat_$volume_flags[vol_idx] := version <> 0;
    if bat_$volume_flags[vol_idx] then
      needs_salvage := 12 in bat_hdr.volume_trouble.members
    else
      needs_salvage := bat_hdr.volume_trouble.value < 0;
    needs_salvage := needs_salvage or (salvage_flag = 1);

    if (not needs_salvage) or else salvage_ok then begin
      bat_$mounted[vol_idx] := true;
      mount_time_high := clockh;
      bat_hdr.volume_trouble.bits.bit_12 := needs_salvage;
      if bat_hdr.step_long = 0 then
        bat_hdr.step_long := 3;
      mount_time_low.node := node_$me;
      boot_time := time_$boot_time;
      dismount_time := clockh;
      salvage_flag := 1;

      hdr := bat_hdr;
      ptab := bat_ptab;
      if version = 0 then begin
        ptab.partition_size := 16#7FFFFFFF;
        ptab.num_partitions := 1;
        ptab.partitions[0].free_count := hdr.free_blocks - 11;
      end;

      with disk_$dvtbl[vol_idx] do begin
        alloc_chunk_size := blocks_per_cyl;
        if part_volx[0] = 1 then
          alloc_chunk_size := alloc_chunk_size * num_parts;
        alloc_chunk_offset := alloc_chunk_size
                              - (lv_start + hdr.first_data_block)
                                mod alloc_chunk_size;
      end;

      dbuf_$set_buff(univ_ptr(label_addr), bat_buf_writeback, status);
    end
    else begin
      dbuf_$set_buff(univ_ptr(label_addr), bat_buf_clean, status);
      status.all := status_$disk_needs_salvaging;
    end;
  end;

done:
  ml_$unlock(ml_$bat_lock);
end;
