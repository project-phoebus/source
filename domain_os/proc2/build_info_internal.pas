{ proc2_$build_info_internal - fill the combined PROC1/PROC2 information
  block for a PROC1 pid and a process-table index.

  Image addresses:
    sau2  0x00E4094C  proc2_$build_info_internal (module-local)

  Assume we're called with ml_$proc2_lock held.

  - The PROC1 half for a pid: PROC1_$GET_INFO's record, priorities,
    SIDs, statistics and CPU usage (cleared for pid 0).
  - The PROC2 half for an index: a bound process's UIDs, group, name
    and accounting, or a zombie's clock and usage; the UNIX ids of the
    process, its parent and debugger.

  Status stored:
    status_$ok: the block was filled
    proc2_$is_current: the pid is the caller's own
    status_$proc2_zombie: a zombie
    proc2_$not_level_2: an entry neither bound nor a zombie
    proc1_$get_info's or acl_$get_pid_sid's status, fail bit set: that
      step failed
}

procedure proc2_$build_info_internal(proc2_index: integer;
                                     proc1_pid: pinteger;
                                     out info: univ proc2_combined_info_t;
                                     out status_ret: status_$t);
begin
  status_ret.all := status_$ok;
  if proc1_pid <> 0 then begin
    proc1_$get_info(proc1_pid, info.proc1_info, status_ret);
    if status_ret.code <> 0 then begin
      status_ret.fail := true;
      return;
    end;
    proc1_$set_priority(proc1_pid, false,
                        info.min_priority, info.max_priority);
    acl_$get_pid_sid(proc1_pid, info.sid, status_ret);
    if status_ret.code <> 0 then begin
      status_ret.fail := true;
      return;
    end;
    info.cpu_time.first :=
      proc2_stats_view_t(proc1_$stats[proc1_pid]).first;
    info.cpu_time.rest :=
      proc2_stats_view_t(proc1_$stats[proc1_pid]).rest;
    proc1_$get_any_cpu_usage(proc1_pid, info.usage.cpu_time,
                             info.usage.counts.stat1, info.usage.counts.stat2);
    info.usage.counts.field_10 := 16#411C;
    if proc1_pid = proc1_$current then
      status_ret.all := proc2_$is_current;
  end
  else begin
    info.proc1_info.flags := [];
    info.proc1_info.usr := 0;
    info.proc1_info.upc := 0;
    info.proc1_info.usp := 0;
    info.proc1_info.usb := 0;
    info.proc1_info.cpu.total.high := 0;
    info.proc1_info.cpu.total.low := 0;
    info.proc1_info.cpu.state := 0;
    info.min_priority := 0;
    info.max_priority := 0;
    info.sid.user_sid := uid_$nil;
    info.sid.group_sid := uid_$nil;
    info.sid.org_sid := uid_$nil;
    info.sid.login_sid := uid_$nil;
    info.sid.pad := 0;
    info.cpu_time.first := 0;
    info.cpu_time.rest[1] := 0;
    info.cpu_time.rest[2] := 0;
    info.cpu_time.rest[3] := 0;
    info.usage.cpu_time.high := 0;
    info.usage.cpu_time.low := 0;
    info.usage.counts.stat2 := 0;
    info.usage.counts.stat1 := 0;
    info.usage.counts.field_10 := 0;
  end;
  if proc2_index <> 0 then
    with proc2_$info_table[proc2_index] do
      if (proc2_pf_bound in flags.bits)
         or else (proc2_pf_zombie in flags.bits) then begin
        if proc2_pf_bound in flags.bits then begin
          info.parent_uid := parent_uid;
          info.cr_rec := cr_rec;
          info.asid := asid;
          proc2_$entry_pgroup_uid(proc2_$info_table[proc2_index],
                                  info.proc_uid_2);
          info.pgroup_uid := info.proc_uid_2;
          proc2_$entry_pgroup_upgid(proc2_$info_table[proc2_index],
                                    info.pgroup_info);
          info.pgroup_flags := info.pgroup_info;
          info.tty_uid := tty_uid;
          if name_len = chr(16#21) then
            info.name_len := 0
          else if name_len = chr(16#22) then
            info.name_len := -1
          else
            info.name_len := ord(name_len);
          info.name := name;
        end
        else begin
          info.parent_uid := uid_$nil;
          info.cr_rec := 0;
          info.asid := 0;
          info.pgroup_uid := uid_$nil;
          info.proc_uid_2 := uid_$nil;
          info.pgroup_flags := 0;
          info.pgroup_info := 0;
          info.tty_uid := uid_$nil;
          info.proc1_info.cpu.total := zombie_usage.cpu_time;
          info.usage := zombie_usage;
          info.name_len := 0;
          status_ret.all := status_$proc2_zombie;
        end;
        info.server_flag := proc2_pf_server in flags.bits;
        info.upid := upid;
        if parent_pgroup_idx <> 0 then
          info.parent_upid :=
            proc2_$info_table[parent_pgroup_idx].upid
        else
          info.parent_upid := 1;
        if debugger_idx <> 0 then
          info.session_upid :=
            proc2_$info_table[debugger_idx].upid
        else
          info.session_upid := 0;
        info.acct.chars := acct.chars;
        info.acct_info := acct_info;
      end
      else begin
        status_ret.all := proc2_$not_level_2;
        info.parent_uid := uid_$nil;
        info.pgroup_uid := uid_$nil;
        info.proc_uid_2 := uid_$nil;
        info.cr_rec := 0;
        info.pgroup_flags := 0;
        info.server_flag := false;
        info.upid := 0;
        info.parent_upid := 0;
        info.pgroup_info := 0;
        info.session_upid := 0;
        info.acct.uid := uid_$nil;
        info.acct.info_len := 0;
        info.name_len := 0;
        info.asid := 0;
        info.tty_uid := uid_$nil;
      end;
end;
