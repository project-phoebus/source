{ debug_setup_internal - attach a process to a debugger.

  Image addresses:
    sau2  0x00E4194C  debug_setup_internal (module-local)

  - The target leaves any earlier debugger's list and goes at the head
    of the new one's, its ptrace options reset; with flag the creation
    record's byte at +0x90 is set (XPD_$WRITE, its status ignored).
  - A suspended target's guardian is woken before and after.

  Status stored: none.
}

procedure debug_setup_internal(target_idx: integer; debugger_idx: integer;
                               flag: boolean);
var
  opts: proc2_$ptrace_opts_t;
  status: status_$t;
begin
  with proc2_$info_table[target_idx]: target,
       proc2_$info_table[debugger_idx]: debugger do begin
    if target.debugger_idx <> 0 then
      debug_unlink_from_list(target_idx);
    target.debugger_idx := debugger_idx;
    target.next_debug_target_idx :=
      debugger.first_debug_target_idx;
    debugger.first_debug_target_idx := target_idx;
    if xpd_pf_suspended in target.flags.bits then
      proc2_$awaken_guardian(target_idx);
    opts := target.ptrace_opts;
    xpd_$reset_ptrace_opts(opts);
    target.ptrace_opts := opts;
    if flag then
      xpd_$write(target.asid,
                 proc2_cr_rec_ptr_t(target.cr_rec_2)^.debug_flag,
                 1, integer32(-1), status);
    if xpd_pf_suspended in target.flags.bits then
      proc2_$awaken_guardian(target_idx);
  end;
end;
