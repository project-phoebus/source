{ proc2_$delete_cleanup - release what the current process holds.

  Image addresses:
    sau2  0x00E743CE  proc2_$delete_cleanup (module-local)

  - Under ml_$proc2_lock the process is made a zombie or its slot
    freed, and its accounting record logged.
  - With no creation record PACCT_$LOG gets the level-1 PID as the exit
    status.

  Status stored: none.
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure proc2_$delete_cleanup;
var
  unused_8: integer32;                    { stand-in, the
                                            TODO(pascal) below }
  saved_tty_uid: uid_$t;
  dir_name: array[1..32] of char;
  dirent: proc2_dirent_t;
  fim_rec: fim_$cleanup_rec_t;
  dropped_uid: uid_$t;
  cr: proc2_cr_rec_ptr_t;
  continuation: rem_name_$continuation_t;
  unused_98: array[1..2] of integer32;    { stand-in }
  cpu_time: time_$clock_t;
  count: linteger;
  i: integer;
  status: status_$t;
  dir_name_len: pinteger;
  old_asid: integer;
  cur_idx: integer;
  idx: integer;
  prev_idx: integer;
  vforked: boolean;
begin
  cur_idx := proc2_$pid_to_index[proc1_$current];
  with proc2_$info_table[cur_idx] do begin
    if proc2_pf_alt_asid in flags.bits then
      old_asid := asid_alt
    else
      old_asid := asid;
    xpd_$cleanup;
    if not (proc2_pf_alt_asid in flags.bits) then begin
      smd_$free_asid(old_asid);
      dma_$free_asid(old_asid);
      scsi_$free_asid(old_asid);
    end;
    if cleanup_flags <> [] then
      proc2_$cleanup_handlers_internal(proc2_$info_table[cur_idx]);
    ml_$lock(ml_$proc2_lock);
    flags.bits := flags.bits - [xpd_pf_debug_target];
    pgroup_cleanup_internal(proc2_$info_table[cur_idx], 0);

    idx := first_debug_target_idx;
    if idx <> 0 then
      repeat
        with proc2_$info_table[idx] do begin
          idx := next_debug_target_idx;
          debug_clear_internal(self_index, true);
        end;
      until idx = 0;
    while first_child_idx <> 0 do
      proc2_$detach_from_parent(first_child_idx, 0);

    case name_len of
      proc2_name_len_none: { empty };
      proc2_name_len_by_uid:
        if proc2_$proc_dir_uid <> uid_$nil then begin
          continuation.all := 1;
          dir_name_len := 0;
          repeat
            dir_$dir_readu(proc2_$proc_dir_uid, dir_name, dir_name_len,
                           continuation, proc2_$delete_dirent_max,
                           proc2_$delete_dirent_size, dirent, count,
                           status);
            if status.all <> status_$ok then exit;
            if dirent.uid = uid then begin
              dir_$dropu(proc2_$proc_dir_uid, dirent.name,
                         dirent.name_len, dropped_uid,
                         status);
              exit;
            end;
          until count = 0;
        end;
      otherwise
        if proc2_$proc_dir_uid <> uid_$nil then
          dir_$dropu(proc2_$proc_dir_uid, name, ord(name_len),
                     dropped_uid, status);
    end;

    vforked := proc2_pf_alt_asid in flags.bits;
    if proc2_pf_alt_asid in flags.bits then begin
      proc2_$uid[asid] :=
        proc2_$info_table[parent_pgroup_idx].uid;
      parent_uid := uid_$nil;
      flags.bits := flags.bits - [proc2_pf_alt_asid];
    end;
    flags.bits := flags.bits - [proc2_pf_bound];
    proc2_$pid_to_index[level1_pid] := 0;

    if not (proc2_pf_init in flags.bits) then
      if (proc2_$sig_cld - 1) in
         proc2_$info_table[parent_pgroup_idx].sig_blocked.blocked_1
      then begin
        ec_$advance(proc2_$ec[parent_pgroup_idx].cr_rec_ec);
        prev_idx :=
          proc2_$info_table[parent_pgroup_idx].first_child_idx;
        if prev_idx = cur_idx then
          prev_idx := 0
        else
          while proc2_$info_table[prev_idx].next_child_sibling
                <> cur_idx do
            prev_idx := proc2_$info_table[prev_idx].next_child_sibling;
        proc2_$detach_from_parent(cur_idx, prev_idx);
      end;

    saved_tty_uid := tty_uid;
    if (debugger_idx <> 0)
       or else not (proc2_pf_init in flags.bits) then
      flags.bits := flags.bits + [proc2_pf_zombie];

    if (debugger_idx <> 0)
       or else not (proc2_pf_init in flags.bits)
       or else pacct_$on then begin
      proc1_$get_cpu_usage(cpu_time, zombie_usage.counts.stat1,
                           zombie_usage.counts.stat2);
      zombie_usage.counts.field_10 := 16#411C;
      cr := proc2_cr_rec_ptr_t(cr_rec_2);
      if cr <> nil then begin
        status := fim_$cleanup(fim_rec);
        if status.all = fault_$cleanup_set then begin
          zombie_counts := cr^.block_1;
          zombie_exit.status := cr^.exit_status;
          zombie_exit.info.all := cr^.status.all;
          zombie_flags.flag_15 := cr^.flag_88;
          zombie_flags.flag_14 := cr^.flag_89;
          zombie_counts[6] := zombie_counts[6]
            + proc1_$stats[proc1_$current].stat[1];
          zombie_counts[8] := zombie_counts[8]
            + proc1_$stats[proc1_$current].stat[2];
          if vforked then begin
            cr^.vfork_time := cpu_time;
            zombie_usage.cpu_time := cr^.vfork_time;
          end
          else begin
            add48(cr^.cpu_time, cpu_time);
            zombie_usage.cpu_time := cr^.cpu_time;
            cr^.counts.stat2 := cr^.counts.stat2
              + zombie_usage.counts.stat2;
            cr^.counts.stat1 := cr^.counts.stat1
              + zombie_usage.counts.stat1;
            cr^.counts.field_10 := zombie_usage.counts.field_10;
            zombie_usage.counts := cr^.counts;
            for i := 1 to 14 do
              zombie_counts[i] := zombie_counts[i] + cr^.block_2[i];
          end;
          fim_$rls_cleanup(fim_rec);
        end
        else
          fim_$pop_signal(fim_rec);
      end;
      pacct_$log(proc2_pf_debug in flags.bits, acl_$used_suser,
                 level1_pid & 16#FF, creation_time,
                 zombie_usage,
                 proc1_$stats[proc1_$current].stat[3],
                 proc1_$stats[proc1_$current].stat[4],
                 saved_tty_uid, acct.uid, acct_info,
                 acct.info_len);
    end;

    if (debugger_idx = 0)
       and then (proc2_pf_init in flags.bits) then begin
      pgroup_cleanup_internal(proc2_$info_table[cur_idx], 1);
      if pad_14 = 0 then
        p2_info_alloc_ptr := next_index
      else
        proc2_$info_table[pad_14].next_index := next_index;
      proc2_$info_table[next_index].pad_14 := pad_14;
      next_index := proc2_$free_list_head;
      proc2_$free_list_head := self_index;
    end
    else
      proc2_$awaken_guardian(self_index);
  end;

  ml_$unlock(ml_$proc2_lock);
  fim_$fp_abort;
  if not vforked then begin
    file_$unlock_all;
    name_$free_asid(old_asid);
    fim_$free_asid(old_asid);
    peb_$proc_cleanup;
    term_$p2_cleanup(old_asid);
    proc2_$uid[old_asid] := proc2_$system_uid;
  end;
  acl_$free_asid(proc1_$current, status);
  if status.code <> 0 then
    crash_system(status);
  proc1_$set_asid(0);
  mst_$free_asid(old_asid, status);
  if status.code <> 0 then
    crash_system(status);
end;

{ TODO(pascal) proc2_$delete_cleanup's frame below the `with' slot, and
  its top

  With the locals in the order above, `dpc --dump-locals' puts every
  addressed local at the SAU2 image's offset and the `with' slot at the
  image's; dpc's frame is smaller.  Below the slot the image addresses only
  three argument temporaries (a word for DIR_$DROPU's ord(name_len) and
  PACCT_$LOG's exit word, and PACCT_$LOG's two flags), and 16 bytes above
  them nothing (the inner `with''s slot, 4 of them, by dpc's model; 12
  unexplained); dpc puts its temporaries right below the slots.  At the
  top, 4 bytes below the reserved slot hold nothing addressed (the
  stand-in unused_8), and so do 8 bytes in the middle and a word (the
  stand-in unused_98 and i's home).  Not known: what the original
  declared there, and where its compiler puts argument temporaries. }

{ TODO(pascal) dpc's code for proc2_$delete_cleanup

  The routine differs from the image, unanalyzed. }
