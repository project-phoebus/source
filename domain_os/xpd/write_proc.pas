{ XPD_$WRITE_PROC - write a stopped target's memory.

  Image addresses:
    sau2  0x00E5B9E2  XPD_$WRITE_PROC

  - As XPD_$READ_PROC, the copy from the caller's memory into the
    target's.

  Status stored:
    xpd_$copy_memory's status: the copy was made
    XPD_$FIND_INDEX's status: no such target, or not stopped
}

procedure xpd_$write_proc(proc_uid: uid_$t; out target_mem: univ xpd_$bytes_t;
                          in len: linteger; in buffer: univ xpd_$bytes_t;
                          out status_ret: status_$t);
var
  st: status_$t;
  index: integer;
begin
  ml_$lock(ml_$proc2_lock);
  index := xpd_$find_index(proc_uid, st);
  ml_$unlock(ml_$proc2_lock);

  if st.all = status_$ok then
    with proc2_$info_table[index] do
      xpd_$copy_memory(asid, integer32(addr(target_mem)), proc1_$as_id,
                       integer32(addr(buffer)), len, st);

  status_ret := st;
end;
