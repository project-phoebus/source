{ XPD_$SET_PTRACE_OPTS - set a process's ptrace options.

  Image addresses:
    sau2  0x00E5AF9E  XPD_$SET_PTRACE_OPTS
    sau9  0x3C4620CA  XPD_$SET_PTRACE_OPTS

  - Under the process-table lock: the nil UID means the calling
    process, else it is looked up; the caller must be the process's
    debugger or the process itself.  The options go into its entry.

  Status stored:
    status_$ok: set
    status_$proc2_proc_not_debug_target: neither
    PROC2_$FIND_INDEX's status: not found
}

procedure xpd_$set_ptrace_opts(proc_uid: uid_$t; opts: xpd_$ptrace_opts_t;
                               out status_ret: status_$t);
var
  st: status_$t;
  index: integer;
begin
  st.all := status_$ok;
  ml_$lock(ml_$proc2_lock);

  if proc_uid = uid_$nil then
    index := proc2_$pid_to_index[proc1_$current]
  else
    index := proc2_$find_index(proc_uid, st);

  if st.all = status_$ok then
    with proc2_$info_table[index] do
      if (proc2_$pid_to_index[proc1_$current] = debugger_idx) or else
         (proc2_$pid_to_index[proc1_$current] = self_index) then
        ptrace_opts := opts
      else
        st.all := status_$proc2_proc_not_debug_target;

  ml_$unlock(ml_$proc2_lock);
  status_ret := st;
end;
