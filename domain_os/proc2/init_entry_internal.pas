{ proc2_$init_entry_internal - initialize a newly allocated process
  entry.

  Image addresses:
    sau2  0x00E732E4  proc2_$init_entry_internal (module-local)

  - A new UID, published in proc2_$uid; a UPID no entry or group uses;
    the creator's session, and a group of its own (an init process) or
    the creator's; links, flags and ptrace options reset.

  Status stored: none.
}

[section(proc2_create_pro, proc2_create_dat)]
procedure proc2_$init_entry_internal(var entry: proc2_info_t);
var
  unused_a: array[1..2] of integer;       { nothing addressed }
  opts: proc2_$ptrace_opts_t;
  status: status_$t;
  creator: proc2_info_ptr_t;
  new_upid: integer;
  pg: integer;
  scan: integer;
  in_use: boolean;
begin
  uid_$gen(entry.uid);
  proc2_$uid[entry.asid] := entry.uid;
  fim_$init_asid(entry.asid);
  entry.cleanup_flags := [];
  repeat
    new_upid := proc2_$next_upid;
    if proc2_$next_upid = 30000 then
      proc2_$next_upid := 16#41
    else
      proc2_$next_upid := proc2_$next_upid + 1;
    in_use := false;
    pg := pgroup_find_by_upgid(new_upid);
    scan := p2_info_alloc_ptr;
    while scan <> 0 do
      with proc2_$info_table[scan] do begin
        if (upid = new_upid)
           or else (session_id = new_upid)
           or else ((pg <> 0) and then (pgroup_table_idx = pg)) then begin

          in_use := true;
          exit;
        end;
        scan := next_index;
      end;
  until not in_use;
  entry.upid := new_upid;
  entry.first_debug_target_idx := 0;
  entry.debugger_idx := 0;
  entry.next_debug_target_idx := 0;
  entry.first_child_idx := 0;
  entry.next_child_sibling := 0;
  creator := addr(proc2_$info_table[
               proc2_$pid_to_index[proc1_$current]]);
  entry.pgroup_table_idx := 0;
  entry.session_id := creator^.session_id;
  if proc2_pf_init in entry.flags.bits then
    pgroup_set_internal(entry, entry.upid, status)
  else
    proc2_$pgroup_inherit_internal(creator^, entry);
  entry.flags.server := proc2_pf_server in creator^.flags.bits;

  entry.name_len := chr(16#21);
  entry.flags.bits := entry.flags.bits
                      - [proc2_pf_mask_saved, proc2_pf_zombie,
                         proc2_pf_stopped, xpd_pf_state_saved,
                         xpd_pf_suspended];
  entry.pad_94 := 0;
  entry.sig_mask_2 := [];
  opts := entry.ptrace_opts;
  xpd_$reset_ptrace_opts(opts);
  entry.ptrace_opts := opts;
end;
