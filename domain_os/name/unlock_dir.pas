{ name_$unlock_dir - release the current process's old-format directory
  lock.

  Image addresses:
    sau2  0x00E54734  name_$unlock_dir

  - A process holding no lock gets status_$ok.  Otherwise the
    directory's mapping is released (MST_$UNMAP_PRIVI) unless NAME keeps
    it mapped, the FILE_$PRIV_LOCK lock released and the locked UID
    cleared.  A fragment of OLD_DIR.

  Status stored:
    status_$ok: no lock held, or released
    file_$priv_unlock's status, fail bit set: the unlock failed
    mst_$unmap_privi's status, fail bit set: the unmap failed
}

procedure name_$unlock_dir(out status_ret: status_$t);
  internal;
var
  dir_uid: uid_$t;
  dtv: time_$clock_t;
  local_status: status_$t;
  handle: integer32;
begin
  dir_uid := name_$lock_uid[proc1_$current];
  handle := name_$lock_handle[proc1_$current];

  if dir_uid.high = 0 then begin
    status_ret.all := status_$ok;
    return;
  end;

  { the mapping, unless NAME keeps it }
  if (name_$wdir_mapped_info[proc1_$as_id].active and then
      (name_$wdir_mapped_info[proc1_$as_id].first_base = handle)) or else
     (name_$ndir_mapped_info[proc1_$as_id].active and then
      (name_$ndir_mapped_info[proc1_$as_id].first_base = handle)) or else
     (name_$node_mapped_info.active and then
      (name_$node_mapped_info.first_base = handle)) or else
     (name_$com_mapped_info.active and then
      (name_$com_mapped_info.first_base = handle)) or else
     (handle = 0) then
    status_ret.all := status_$ok
  else
    mst_$unmap_privi(3, dir_uid, handle, 65536, proc1_$as_id,
                     status_ret);

  { the lock }
  discard(file_$priv_unlock(dir_uid, name_$lock_slot[proc1_$current],
                            name_$lock_mode[proc1_$current], proc1_$as_id,
                            false, 0, 0, 0, dtv, local_status));
  name_$lock_uid[proc1_$current].high := 0;

  if status_ret.code = 0 then
    status_ret := local_status;
  if status_ret.all <> status_$ok then
    status_ret.fail := true;
end;
