{ XPD_$READ_PROC_ASYNC - read a target's memory without its being
  stopped.

  Image addresses:
    sau2  0x00E5B88E  XPD_$READ_PROC_ASYNC

  - Under the process-table lock the target is found; the caller must
    be its debugger or have debug rights over it.  Then its memory is
    copied into the caller's.

  Status stored:
    xpd_$copy_memory's status: the copy was made
    status_$proc2_permission_denied: no debug rights
    PROC2_$FIND_INDEX's status: not found
}

procedure xpd_$read_proc_async(proc_uid: uid_$t; in target_mem: univ xpd_$bytes_t;
                               in len: linteger; out buffer: univ xpd_$bytes_t;
                               out status_ret: status_$t);
var
  st: status_$t;
  index: integer;
begin
  ml_$lock(ml_$proc2_lock);
  index := proc2_$find_index(proc_uid, st);
  ml_$unlock(ml_$proc2_lock);

  if st.all = status_$ok then
    with proc2_$info_table[index] do
      if (debugger_idx = proc2_$pid_to_index[proc1_$current]) or else
         acl_$check_debug_rights(proc1_$current, level1_pid) then
        xpd_$copy_memory(proc1_$as_id, integer32(addr(buffer)), asid,
                         integer32(addr(target_mem)), len, st)
      else
        st.all := status_$proc2_permission_denied;

  status_ret := st;
end;
