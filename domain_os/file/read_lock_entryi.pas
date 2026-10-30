{ FILE_$READ_LOCK_ENTRYI - the next lock of a volume or of an address
  space, as a lock record.

  Image addresses:
    sau2  0x00E6093C  FILE_$READ_LOCK_ENTRYI

  - The UID names a logical volume (first byte not 0), an address space
    (first byte 0, second 1, its word 0..57), or else the whole table.
  - Under the lock-table lock the first lock from the caller's index on
    (0 meaning 1) is turned into a lock record and the index moved past
    it; a volume walk checks the holder and skips a lock given up.
  - The "no check" exit reports 16#F000C; the "nothing found" exit
    copies out the local record.

  Status stored:
    status_$ok: a lock was found
    disk_$lvuid_to_volx's status: the volume is not known
    status_$volume_unable_to_dismount_boot_volume: the boot volume
    file_$obj_not_locked_by_this_process: none found (index 16#FFFF,
      "no more lock table entries")
    file_$verify_lock_holder's status: the holder check
}

procedure file_$read_lock_entryi(file_uid: uid_$t; in out index: pinteger;
                                 out info_out: file_$lock_info_t;
                                 out status_ret: status_$t);
var
  info: file_$lock_info_t;
  local_status: status_$t;
  found_entry: pinteger;
  volx_out: integer;
  is_per_asid: boolean;
  byte0_word: integer;
  start: pinteger;
  volx: integer;
  asid: integer;
  slot: pinteger;
  i: pinteger;
begin
  is_per_asid := false;
  start := index;
  if start = 0 then
    start := 1;

  { what to walk }
  byte0_word := file_$uid_view_t(file_uid).b0;
  if byte0_word <> 0 then begin
    disk_$lvuid_to_volx(file_uid, volx_out, local_status);
    volx := volx_out;
    if local_status.all <> status_$ok then begin
      status_ret := local_status;
      return;
    end;
    if volx = cal_$boot_volx then begin
      status_ret.all := status_$volume_unable_to_dismount_boot_volume;
      return;
    end;
  end
  else begin
    volx := 0;
    if (file_$uid_view_t(file_uid).w1 <= 57) and then
       (file_$uid_view_t(file_uid).b1 = 1) and then
       (file_$uid_view_t(file_uid).w1 >= 0) then begin
      is_per_asid := true;
      asid := file_$uid_view_t(file_uid).w1;
    end;
  end;

  repeat
    local_status.all := file_$obj_not_locked_by_this_process;
    found_entry := 0;
    ml_$lock(ml_$file_lock_lock);

    { the next lock }
    if is_per_asid then begin
      for slot := start to file_$lock_table2[asid] do
        if file_$lock_table[asid, slot] <> 0 then begin
          start := slot + 1;
          found_entry := file_$lock_table[asid, slot];
          exit;
        end;
    end
    else
      for i := start to file_$lot_high do
        with file_$lock_entries[i] do
          if (state.refcount <> 0) and then
             ((volx = 0) or else
              ((not state.remote) and then
               (state.loc_rights = volx))) then begin
            start := i + 1;
            found_entry := i;
            exit;
          end;

    if found_entry = 0 then begin
      ml_$unlock(ml_$file_lock_lock);
      start := 16#FFFF;
      exit;
    end;

    { the lock record }
    with file_$lock_entries[found_entry] do begin
      info.file_uid := uid;
      info.side := state.side;
      info.mode := state.mode;
      if is_per_asid then
        info.sequence := state.refcount
      else
        info.sequence := sequence;
      info.context := context;
      if state.remote then begin
        info.holder := node;
        info.owner_node := node_$me;
        info.remote_info := network_$me;
      end
      else begin
        info.holder.node_low := node_$me;
        info.holder.node_high := network_$me;
        info.owner_node := node.node_low;
        info.remote_info := node.node_high;
      end;
    end;
    ml_$unlock(ml_$file_lock_lock);

    if (byte0_word = 0) and then (file_uid.low <> 0) then
      exit;
    file_$verify_lock_holder(info, local_status);
  until local_status.all <> file_$object_not_locked_by_this_process;

  status_ret := local_status;
  info_out := info;
  index := start;
end;
