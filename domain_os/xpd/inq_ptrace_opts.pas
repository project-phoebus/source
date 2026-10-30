{ XPD_$INQ_PTRACE_OPTS - read a process's ptrace options.

  Image addresses:
    sau2  0x00E5B076  XPD_$INQ_PTRACE_OPTS
    sau9  0x3C4621A4  XPD_$INQ_PTRACE_OPTS

  - As XPD_$SET_PTRACE_OPTS, the options copied out of the entry under
    the lock, and to the caller only after a good status.

  Status stored:
    status_$ok: read
    status_$proc2_proc_not_debug_target: neither
    PROC2_$FIND_INDEX's status: not found
}

procedure xpd_$inq_ptrace_opts(proc_uid: uid_$t; out opts: xpd_$ptrace_opts_t;
                               out status_ret: status_$t);
var
  st: status_$t;
  index: integer;
  local_opts: xpd_$ptrace_opts_t;
begin
  st.all := status_$ok;
  ml_$lock(ml_$proc2_lock);

  if proc_uid = uid_$nil then
    index := proc2_$pid_to_index[proc1_$current]
  else
    index := proc2_$find_index(proc_uid, st);

  if st.all = status_$ok then
    with proc2_$info_table[index] do
      if (proc2_$pid_to_index[proc1_$current] = self_index) or else
         (proc2_$pid_to_index[proc1_$current] = debugger_idx) then
        local_opts := ptrace_opts
      else
        st.all := status_$proc2_proc_not_debug_target;

  ml_$unlock(ml_$proc2_lock);
  status_ret := st;
  if st.all = status_$ok then
    opts := local_opts;
end;
