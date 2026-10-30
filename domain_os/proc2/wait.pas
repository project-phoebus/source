{ PROC2_$WAIT - wait for a child to stop or die (4.3BSD wait4).

  Image addresses:
    sau2  0x00E3FDD0  PROC2_$WAIT
    sau9  0x3C447260  PROC2_$WAIT

  - The pid selects the children: -1 any, > 0 that UNIX pid (one outside
    65..30000 finds none), 0 the waiter's group, < 0 the group -pid.
  - Under ml_$proc2_lock the child list and the debug target list are
    tried; the first reported ends the wait.  Otherwise, unless WNOHANG,
    it waits on the child-change and quit eventcounts and starts again.

  Status stored:
    status_$ok: a child was reported, or none yet under WNOHANG
    status_$proc2_wait_found_no_children: none qualified
    ec2_$wait_quit: a quit came first
}

function proc2_$wait(in options: proc2_$wait_options_t;
                     in pid: integer;
                     out result: proc2_$wait_result_t;
                     out status_ret: status_$t): integer;
label
  loop_top, no_children;
var
  local: proc2_$wait_result_t;
  vals: array[1..2] of integer32;
  ecs: array[1..2] of ec_$eventcount_ptr_t;
  target_pgroup: integer;
  helper_pid: integer;
  prev: integer;
  found_zombie: boolean;
  found_live: boolean;
  qualified: boolean;
  wait_pgroup: boolean;
  wait_specific: boolean;
  wait_any: boolean;
  opt: proc2_$wait_options_t;
  cur_idx: integer;
  current: proc2_info_ptr_t;
  child: proc2_info_ptr_t;
  target_upid: integer;
  idx: integer;
begin
  proc2_$wait := -1;
  status_ret.all := status_$ok;
  local.flag_64 := false;
  result.flag_64 := false;
  opt := options;
  cur_idx := proc2_$pid_to_index[proc1_$current];
  current := addr(proc2_$info_table[cur_idx]);
  wait_any := false;
  wait_specific := false;
  wait_pgroup := false;
  if pid = -1 then
    wait_any := true
  else if pid > 0 then begin
    wait_specific := true;
    target_upid := pid;
  end
  else if pid = 0 then begin
    wait_pgroup := true;
    target_pgroup := current^.pgroup_table_idx;
  end
  else begin
    wait_pgroup := true;
    target_pgroup := pgroup_find_by_upgid(abs(pid));
  end;
  if (pid > 0)
     and then ((pid > 30000) or else (pid < 16#41)) then
    goto no_children;

loop_top:
  if (current^.first_child_idx = 0)
     and then (current^.first_debug_target_idx = 0) then
    goto no_children;
  ml_$lock(ml_$proc2_lock);
  qualified := false;
  prev := 0;

  idx := current^.first_child_idx;
  if idx <> 0 then
    repeat
      child := addr(proc2_$info_table[idx]);
      with child^ do
        if current^.pad_18[1] = pad_18[2] then
          if wait_any
             or else (wait_specific
                      and then (target_upid = upid))
             or else (wait_pgroup
                      and then (target_pgroup = pgroup_table_idx)) then
            begin
            qualified := true;
            proc2_$wait_try_live_child(idx, opt, cur_idx, prev,
                                       found_live, local,
                                       helper_pid);
            if found_live then begin
              ml_$unlock(ml_$proc2_lock);
              result := local;
              proc2_$wait := helper_pid;
              return;
            end;
          end;
      prev := idx;
      idx := child^.next_child_sibling;
    until idx = 0;

  idx := current^.first_debug_target_idx;
  if idx <> 0 then
    repeat
      child := addr(proc2_$info_table[idx]);
      if wait_any
         or else (wait_specific
                  and then (target_upid = child^.upid))
         or else (wait_pgroup
                  and then (target_pgroup = child^.pgroup_table_idx)) then
        begin
        qualified := true;
        proc2_$wait_try_zombie(idx, opt, found_zombie, local,
                               helper_pid);
        if found_zombie then begin
          ml_$unlock(ml_$proc2_lock);
          result := local;
          proc2_$wait := helper_pid;
          return;
        end;
      end;
      idx := child^.next_debug_target_idx;
    until idx = 0;

  ecs[1] := addr(proc2_$ec[current^.self_index].cr_rec_ec);
  ecs[2] := addr(fim_$quit_ec[current^.asid]);
  vals[1] := ec_$read(proc2_$ec[current^.self_index].cr_rec_ec) + 1;

  vals[2] := fim_$quit_value[current^.asid] + 1;
  ml_$unlock(ml_$proc2_lock);
  if not qualified then begin
  no_children:
    status_ret.all := status_$proc2_wait_found_no_children;
    return;
  end;
  if proc2_$wait_nohang in opt then begin
    proc2_$wait := 0;
    return;
  end;
  if ec_$waitn(ecs, vals, 2) <> 2 then
    goto loop_top;
  fim_$quit_value[current^.asid] :=
    fim_$quit_ec[current^.asid].value;
  status_ret.all := ec2_$wait_quit;
end;
