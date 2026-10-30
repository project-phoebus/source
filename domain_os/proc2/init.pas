{ PROC2_$INIT - set up the level-2 process table and process 1, and find
  process 2's program.

  Image addresses:
    sau2  0x00E303D8  PROC2_$INIT
    sau9  0x3C436418  PROC2_$INIT

  - The UIDs, the tables, the free list of slots 2..70 and process 1's
    entry are set up, its creation-record and stack areas mapped and the
    boot flags recorded; a tape or floppy boot when the mode asks.
  - Otherwise /sys/boot_shell is resolved, locked and mapped per its
    10-byte header; the result is the program's entry point.
  - An exit after OS_$BOOT_ERRCHK stores no result.

  Status stored:
    the last step's status: the program was found
    the failed step's status: a step OS_$BOOT_ERRCHK reports (the
      tape's or floppy's boot, the resolve, lock or maps)
}

[section(os_init_proc, os_init_data)]
function proc2_$init(in ws_mode: univ proc2_$ws_mode_t;
                     out status: status_$t): univ_ptr;
var
  boot_shell_uid: uid_$t;
  unused_0e: array[1..3] of integer;      { nothing reaches
                                            it }
  hdr: proc2_boot_shell_hdr_t;
  entry_point: integer32;
  unused_20: integer32;                   { nothing reaches
                                            it }
  lock_info: integer32;
  unused_28: integer32;                   { nothing reaches
                                            it }
  map_info: integer32;
  mapped_va: integer32;
  unused_34: integer32;                   { nothing reaches
                                            it }
  min_pri: integer;
  max_pri: integer;
  mapped: univ_ptr;
  boot_stack: proc2_boot_stack_ptr_t;
  i: integer;
  unused_4c: array[1..10] of char;        { nothing reaches it }
  ok: boolean;
begin
  uid_$gen(proc2_$system_uid);
  uid_$gen(proc2_$uid[1]);
  max_pri := 16;
  min_pri := 16;
  proc1_$set_priority(proc1_$current, true, min_pri, max_pri);

  proc2_$uid[0] := proc2_$system_uid;
  for i := 2 to 57 do
    proc2_$uid[i] := proc2_$system_uid;
  for i := 2 to 64 do
    proc2_$pid_to_index[i] := 0;
  for i := 1 to 70 do
    proc2_$pgroup_table[i].ref_count := 0;
  proc2_$free_list_head := 2;
  for i := 2 to 70 do
    with proc2_$info_table[i] do begin
      next_index := i + 1;
      parent_uid := uid_$nil;
      flags.bits := flags.bits - [7, 8];
      self_index := i;
    end;
  proc2_$info_table[70].next_index := 0;
  p2_info_alloc_ptr := 1;
  proc2_$pid_to_index[1] := 1;

  with proc2_$info_table[1] do begin
    next_index := 0;
    pad_14 := 0;
    asid := 1;
    self_index := 1;
    uid := proc2_$uid[1];
    level1_pid := proc1_$current;
    cleanup_flags := [];
    first_child_idx := 0;
    next_child_sibling := 0;
    parent_pgroup_idx := 0;
    first_debug_target_idx := 0;
    debugger_idx := 0;
    next_debug_target_idx := 0;
    upid := 1;
    session_id := 0;
    pgroup_table_idx := 0;
    sig_pending := [];
    sig_blocked.blocked_1 := [];
    sig_blocked.blocked_2 := [];
    sig_mask_3 := [];
    sig_mask_2 := [];
    sig_mask_1 := [];
    flags.bits := flags.bits - [10, 14];
    pad_18[1] := 0;
    pad_18[2] := 0;
    pad_94 := 0;
    flags.zombie := false;
    flags.init := true;
    flags.bits := flags.bits - [4, 6, 9, 11, 12];
    name_len := chr(16#21);
    cr_rec_2 := as_$info.cr_rec;
    tty_uid := uid_$nil;
    acct.uid := uid_$nil;
    acct.info_len := 0;
    ec_$init(proc2_$ec[self_index].fork_ec);
    ec_$init(proc2_$ec[self_index].cr_rec_ec);

    mst_$map_area_at(as_$info.cr_rec, as_$info.cr_rec_file_size,
                     16#4000, false, parent_uid, status);
    if not os_$boot_errchk('unable to map%', 'creation record area',
                           20, status) then
      return;
    mst_$map_area_at(as_$info.stack_file_low,
                     as_$info.init_stack_file_size,
                     16#4000, true, stack_uid, status);
    if not os_$boot_errchk('unable to map%', 'initial area', 12,
                           status) then
      return;

    flags.bits := flags.bits + [7, 8];
    cr_rec := as_$info.stack_high;
    proc2_$boot_flags.w := proc2_$boot_flags.w & 16#C000;
    proc2_$boot_flags.normal_mode := mmu_$normal_mode;
    proc2_$boot_flags.no_dtty := not dtty_$use_dtty;
    boot_stack := proc2_boot_stack_ptr_t(cr_rec - 6);
    boot_stack^.zero := 0;
    boot_stack^.flags := proc2_$boot_flags.w;
  end;

  if proc2_$boot_from_tape in ws_mode then begin
    ok := tape_$boot(entry_point, status);
    proc2_$init := univ_ptr(entry_point);
    if ok then
      return;
  end;
  if proc2_$boot_from_floppy in ws_mode then begin
    ok := flop_$boot(entry_point, status);
    proc2_$init := univ_ptr(entry_point);
    if ok then
      return;
  end;

  name_$resolve('`node_data/proc_dir', 19, proc2_$proc_dir_uid,
                status);
  if status.all <> status_$ok then
    proc2_$proc_dir_uid := uid_$nil;

  name_$resolve('/sys/boot_shell', 15, boot_shell_uid, status);

  if not os_$boot_errchk('unable to resolve%', '/sys/boot_shell', 15,
                         status) then
    return;
  file_$lock(boot_shell_uid, 0, 1, false, lock_info, status);

  if not os_$boot_errchk('unable to lock%', '/sys/boot_shell', 15,
                         status) then
    return;
  mapped := mst_$map(boot_shell_uid, 0, 10, 3, 0, false, map_info,
                     status);
  if not os_$boot_errchk('unable to map for read%', '/sys/boot_shell',
                         15, status) then
    return;
  hdr := proc2_boot_shell_hdr_ptr_t(mapped)^;
  mapped_va := integer32(mapped);
  mst_$unmap(boot_shell_uid, mapped_va, map_info, status);
  if not os_$boot_errchk('unable to unmap%', '/sys/boot_shell', 15,
                         status) then
    return;
  mst_$map_at(hdr.map_va, boot_shell_uid, 0, 16#7FFFFFFF, 3, 0, false,
              map_info, status);
  if not os_$boot_errchk('unable to map%', '/sys/boot_shell', 15,
                         status) then
    return;
  proc2_$init := univ_ptr(hdr.entry_pc);
end;

{ TODO(pascal) PROC2_$INIT's frame

  The SAU2 frame is 0x50 bytes, of which the image addresses 41; the
  holes are kept by the stand-ins and the register-held locals' homes,
  in the image's order.  The four bytes above
  lock_info and map_info may be 8-byte records for FILE_$LOCK's and the
  MST routines' arguments where the headings here give a longword
  (file/file.ins.pas, mst/mst.ins.pas); the big hole may be register
  homes.  Settle with the other unaddressed frames and those headings. }
