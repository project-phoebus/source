{ PROC2_$GET_INFO - the combined PROC1/PROC2 information block for a
  process UID.

  Image addresses:
    sau2  0x00E4086E  PROC2_$GET_INFO

  - Under ml_$proc2_lock a live process or a zombie has
    proc2_$build_info_internal fill a local block, copied out after the
    unlock, up to the caller's length (at most 228 bytes).
  - The frame holds a second block of the type nothing addresses
    (unused_1d0, as PROC2_$INFO's).

  Status stored:
    proc2_$build_info_internal's status: a live process or a zombie
    proc2_$find_index' status: any other lookup
}

procedure proc2_$get_info(proc_uid: uid_$t;
                          out info: univ proc2_$info_buf_t;
                          in info_len: pinteger;
                          out status_ret: status_$t);
var
  local_info: proc2_$info_buf_t;
  unused_1d0: proc2_$info_buf_t;          { the stand-in }
  len: pinteger;
  idx: integer;
  status: status_$t;
  n: pinteger;
  i: integer;
begin
  len := info_len;
  ml_$lock(ml_$proc2_lock);
  idx := proc2_$find_index(proc_uid, status);
  if (status.code = 0)
     or else (status.all = status_$proc2_zombie) then begin
    if status.all = status_$proc2_zombie then
      proc2_$build_info_internal(idx, 0, local_info, status)

    else
      proc2_$build_info_internal(idx,
                                 proc2_$info_table[idx].level1_pid,
                                 local_info, status);
    ml_$unlock(ml_$proc2_lock);
    if len < 228 then
      n := len
    else
      n := 228;
    for i := 1 to n do
      info[i] := local_info[i];
  end
  else
    ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
