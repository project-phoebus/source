{ XPD_$FIND_INDEX - the process-table index of a target the caller may
  operate on.

  Image addresses:
    sau2  0x00E5AF38  XPD_$FIND_INDEX

  - The UID's index (PROC2_$FIND_INDEX) is returned whatever the
    status; the caller must be the target's debugger and the target
    stopped (flag 4).

  Status stored:
    PROC2_$FIND_INDEX's status: found and stopped, or not found
    status_$proc2_proc_not_debug_target: another's target
    status_$xpd_target_not_suspended: not stopped
}

function xpd_$find_index(in proc_uid: uid_$t; out status_ret: status_$t): integer;
var
  index: integer;
begin
  index := proc2_$find_index(proc_uid, status_ret);
  xpd_$find_index := index;
  if status_ret.all <> status_$ok then
    return;

  with proc2_$info_table[index] do
    if debugger_idx <> proc2_$pid_to_index[proc1_$current] then
      status_ret.all := status_$proc2_proc_not_debug_target
    else if not (xpd_pf_suspended in flags.bits) then
      status_ret.all := status_$xpd_target_not_suspended;
end;
