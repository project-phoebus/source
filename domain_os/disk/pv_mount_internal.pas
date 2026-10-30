{ disk_$pv_mount_internal - mount or assign a physical volume and the
  other members of its striped set.

  Image addresses:
    sau2  0x00E6C116  disk_$pvmi_find_slot (nested)
    sau2  0x00E6C21A  disk_$validate_pv_label (nested)
    sau2  0x00E6C2BC  disk_$pv_mount_internal (module-local)

  - Under MOUNT_LOCK the nested finder gives the driver and a free slot;
    the driver's dinit fills the geometry.
  - A mount (type 2), or a type-1 assignment on unit type 0, reads and
    checks the PV label and takes the label's geometry and UID.
  - A striped set's further members are found, initialized and checked
    against the first.  On failure every claimed slot is cleared and
    its device shut down.  The mount is audited.
  - The audit logs AUDIT_$ASSIGN_DISK_EU in every case; a member's
    num_parts is its place; the member's dinit gets addr_end.
  - The result is the first slot's index, also on a failure; the finder
    takes the last free slot.

  Status stored:
    status_$ok: the volume was mounted or assigned
    disk_$pvmi_find_slot's, the dinit's or disk_$validate_pv_label's
      status: those failed
    status_$disk_striping_not_supported: a striped set the driver
      cannot stripe
    status_$invalid_physical_volume_label: a member's label does not
      match
}

function disk_$pv_mount_internal(mount_type: integer; unit_type: integer;
                                 device: integer; unit: pinteger;
                                 var unit_id_ptr: pinteger;
                                 var num_blocks_ptr: integer32;
                                 var sec_per_track_ptr: pinteger;
                                 var num_heads_ptr: pinteger;
                                 var pvlabel_info: univ disk_$pvlabel_info_t;
                                 var status: status_$t): integer; internal;
label
  10;
var
  { The unit's data block, 0x64 bytes (disk/disk_vol.pas). }
  vol_template: static disk_$volume_t :=
    [addr_start := 1, sec_per_track := 1, num_heads := 2,
     blocks_per_cyl := 4, bat_step := 1, num_parts := 1];
                                          { +0x00, 0x48 bytes: the six
                                            fields set, the rest zero }
  log2_table: static array[0..9] of pinteger :=
    [0, 0, 1, 0, 2, 0, 0, 0, 3, 0];       { +0x48 }
  pow2_table: static array[0..3] of pinteger :=
    [1, 2, 4, 0];                         { +0x5C }

  vol_mask: disk_$vol_set_t;
  pv_label: disk_$pv_label_ptr_t;
  dev_entry: disk_$device_entry_ptr_t;
  member_dev: disk_$device_entry_ptr_t;
  dbuf_st: status_$t;
  vols: disk_$part_list_t;
  member_geom: disk_$pvlabel_buf_t;
  member_unit_id: pinteger;
  pv_uid: uid_$t;
  part_dev: disk_$part_list_t;
  interleave: pinteger;
  part: integer;
  member_device: integer;
  member_unit: pinteger;
  first: integer;
  n_parts: pinteger;
  member: integer;
  part_num: pinteger;
  i: integer;
  audit_rec: array[1..3] of integer;
  audit_st: pinteger;
  audit_eu: uid_$t;

  { disk_$pvmi_find_slot - find the device's driver and a volume slot.

    Image addresses:
      sau2  0x00E6C116  disk_$pvmi_find_slot (nested)

    - A physical-volume slot of the same unit and driver is reported,
      its geometry copied into the parent's cells; else a free slot is
      the result.

    Status stored:
      status_$ok: a free slot
      status_$io_controller_not_found: no driver entry (result 0)
      status_$disk_already_mounted: a mount of a mounted volume
      status_$volume_in_use: the volume is in use
      status_$volume_table_full: no slot at all
  }

  function disk_$pvmi_find_slot(ctype: integer; cnum: integer;
                                unit: pinteger;
                                var dev: disk_$device_entry_ptr_t;
                                var status: status_$t): integer;
  var
    slot: integer;
    i: integer;
  begin
    dev := disk_$get_drte(ctype, cnum);
    if dev = nil then begin
      status.all := status_$io_controller_not_found;
      disk_$pvmi_find_slot := 0;
      return;
    end;

    status.all := status_$ok;
    slot := 0;
    for i := 1 to 10 do
      with disk_$dvtbl[i] do
        if mount_state = 0 then
          slot := i
        else if (unit = dev_unit) and then (dev_info = dev) and then
                (lv_start = 0) then begin
          if (mount_type = 2) and then (mount_state = 3) then
            status.all := status_$disk_already_mounted
          else
            status.all := status_$volume_in_use;
          unit_id_ptr := unit_id;
          num_blocks_ptr := addr_start * num_parts;
          sec_per_track_ptr := sec_per_track;
          num_heads_ptr := num_heads;
          pvlabel_info.w_06 := pow2_table[sector_size_code];
          slot := i;
          exit;
        end;

    if slot = 0 then
      status.all := status_$volume_table_full;
    disk_$pvmi_find_slot := slot;
  end;

  { disk_$validate_pv_label - read and check a volume's PV label.

    Image addresses:
      sau2  0x00E6C21A  disk_$validate_pv_label (nested)

    - Block 0 is read (nil on a failed read) and returned held.

    Status stored:
      status_$ok: the label is good
      disk_$get_block's status: the read failed
      status_$invalid_physical_volume_label: an illegal striping mode, a
        version above 1, no `APOLLO', or a member count other than 8,
        4, 2, 0, 1
  }

  function disk_$validate_pv_label(vol_idx: integer;
                                   var status: status_$t):
                                   disk_$pv_label_ptr_t;
  var
    pv_label: disk_$pv_label_ptr_t;
  begin
    pv_label := disk_$get_block(vol_idx, 0, pv_label_$uid, 0, 0, 0, status);
    if status.all <> status_$ok then begin
      disk_$validate_pv_label := nil;
      return;
    end;

    with pv_label^ do
      if ((num_parts > 1) and not (interleave in [0, 1, 2, 4, 5])) or else
         ((version > 1) or (apollo <> 'APOLLO')) or else
         ((num_parts <> 8) and then (num_parts <> 4) and then
          (num_parts <> 2) and then (num_parts <> 0) and then
          (num_parts <> 1)) then
        status.all := status_$invalid_physical_volume_label;

    disk_$validate_pv_label := pv_label;
  end;

begin
  vol_mask := [];
  pv_label := nil;
  ml_$exclusion_start(mount_lock);
  first := disk_$pvmi_find_slot(unit_type, device, unit, dev_entry, status);
  if status.all <> status_$ok then
    goto 10;

  if mount_type <> 2 then
    proc2_$set_cleanup(5);
  disk_$diskless_init;

  with disk_$dvtbl[first] do begin
    disk_$dvtbl[first] := vol_template;
    dev_info := dev_entry;
    dev_unit := unit;
    part_volx[1] := first;
    n_parts := 1;
    interleave := 0;
    vols[1] := first;
    status.all := disk_$mnt_dinit(unit, dev_entry, num_blocks_ptr,
                                  sec_per_track_ptr, num_heads_ptr,
                                  pvlabel_info, unit_id_ptr);
    if status.all <> status_$ok then
      goto 10;

    mount_proc := proc1_$current;
    unit_id := unit_id_ptr;
    if mount_type <> 2 then begin
      addr_start := num_blocks_ptr;
      addr_end := num_blocks_ptr;
      sec_per_track := sec_per_track_ptr;
      num_heads := num_heads_ptr;
      mount_state := 2;
      sector_size_code := log2_table[pvlabel_info.w_06];
    end;

    if (mount_type <> 2) and then
       ((mount_type <> 1) or else (unit_type <> 0)) then
      goto 10;
    mount_state := 1;
    vol_mask := [first];
    pv_label := disk_$validate_pv_label(first, status);
    if status.all <> status_$ok then
      goto 10;

    if mount_type = 2 then begin
      if (unit_type = 4) and then ((pv_label^.drive_type & 16#FF00) <> 0) then
        unit_id := pv_label^.drive_type;
      addr_start := pv_label^.total_blocks;
      addr_end := pv_label^.addr_end;
      if addr_end = 0 then
        addr_end := 16#FFFFFF;
      sec_per_track := pv_label^.blocks_per_track;
      num_heads := pv_label^.tracks_per_cyl;
      lv_uid := pv_label^.pv_uid;
      sector_size_code := log2_table[pv_label^.sectors_per_block];
      pvlabel_info.w_04 := pv_label^.precomp_cyl;
      if (unit_type = 4) or else ((unit_id_ptr & 16#FF00) = 16#300) then begin
        status.all := disk_$mnt_dinit(unit, dev_entry, addr_start,
                                      sec_per_track, num_heads,
                                      pvlabel_info, unit_id_ptr);
        if status.all <> status_$ok then
          goto 10;
      end;
    end;

    if n_parts <= pv_label^.num_parts then
      n_parts := pv_label^.num_parts;
    pv_uid := pv_label^.pv_uid;
    part_dev := pv_label^.part_dev;
    part_num := pv_label^.part_num;
    interleave := pv_label^.interleave;
    disk_$set_buff(pv_label, 8, dbuf_st);
    pv_label := nil;

    if (n_parts <= 1) or else (unit_type <> 0) then
      goto 10;
    if (dev_entry^.unit_count & 16#200) <> 0 then begin
      status.all := status_$disk_striping_not_supported;
      goto 10;
    end;
    if part_num <> 1 then begin
      status.all := status_$invalid_physical_volume_label;
      goto 10;
    end;

    { the other members }
    for part := 2 to n_parts do begin
      member_device := rshft(part_dev[part], 8) & 7;
      member_unit := rshft(part_dev[part] & 16#F0, 4);
      member := disk_$pvmi_find_slot(unit_type, member_device, member_unit,
                                     member_dev, status);
      if status.all <> status_$ok then
        goto 10;

      with disk_$dvtbl[member] do begin
        disk_$dvtbl[member] := disk_$dvtbl[first];
        part_volx[1] := member;
        vols[part] := member;
        dev_info := member_dev;
        dev_unit := member_unit;
        mount_state := 1;
        vol_mask := vol_mask + [member];

        status.all := disk_$mnt_dinit(member_unit, member_dev, addr_end,
                                      sec_per_track, num_heads, member_geom,
                                      member_unit_id);
        if status.all <> status_$ok then
          goto 10;
        pv_label := disk_$validate_pv_label(member, status);
        if status.all <> status_$ok then
          goto 10;

        mount_state := 4;
        part_volx[1] := first;
        num_parts := part;
        if (pv_uid <> pv_label^.pv_uid) or else (part <> pv_label^.part_num) then
        begin
          status.all := status_$invalid_physical_volume_label;
          goto 10;
        end;

        disk_$set_buff(pv_label, 8, dbuf_st);
        pv_label := nil;
      end;
    end;
  end;

10:
  if pv_label <> nil then
    disk_$set_buff(pv_label, 8, dbuf_st);

  if status.all = status_$ok then
    with disk_$dvtbl[first] do begin
      if mount_type = 2 then
        mount_state := 3
      else
        mount_state := 2;
      part_list := vols;
      num_parts := n_parts;
      part_volx[0] := interleave;

      case interleave of
        1: begin
          stripe_blk_mask := n_parts - 1;
        end;
        2: begin
          stripe_vol_mask := n_parts - 1;
        end;
        3: { empty };
        4: begin
             stripe_blk_mask := 1;
             stripe_vol_mask := n_parts div 2 - 1;
           end;
        5: begin
             stripe_blk_mask := 3;
             stripe_vol_mask := n_parts div 4 - 1;
           end;
      end;

      stripe_blk_shift := log2_table[stripe_blk_mask + 1];
      stripe_vol_shift := log2_table[stripe_vol_mask + 1];
      blocks_per_cyl := rshft(num_heads * sec_per_track, sector_size_code);
      addr_start := addr_start * n_parts;
      addr_end := addr_end * n_parts;
    end
  else
    { undo every claimed slot }
    for i := 1 to 10 do
      if i in vol_mask then
        with disk_$dvtbl[i] do begin
          mount_state := 0;
          disk_$invalidate(i);
          disk_$shutdown(dev_info^, dev_unit);
        end;

  ml_$exclusion_stop(mount_lock);
  disk_$pv_mount_internal := first;

  if audit_$enabled then begin
    if mount_type = 2 then
      audit_eu := audit_$mount_disk_eu
    else
      audit_eu := audit_$assign_disk_eu;
    audit_rec[1] := unit_type;
    audit_rec[2] := device;
    audit_rec[3] := unit;
    if status.all = status_$ok then
      audit_st := 0
    else
      audit_st := 1;
    audit_$log_event(audit_$assign_disk_eu, audit_st, status, audit_rec, 6);
  end;
end;
