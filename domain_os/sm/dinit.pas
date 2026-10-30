{ SM_$DINIT - bring a storage module drive up.

  Image addresses:
    sau5  0x00E6F40C  SM_$DINIT

  - The driver is wired and the command block mapped first; an
    MMU_$VTOP failure crashes the system.
  - Under the controller's lock, at most two tries of reset, start, and
    a seek to cylinder 0.  When both starts fail the status is the last
    reset's (0): the start's own status is only tested.
  - A volume whose block count is not positive gets the drive's
    geometry: 18 sectors a track, 19 heads, 281466 blocks.

  Returns:
    0: the drive is up
    sm_$reset's status: a reset failed
    sm_$seek's status: the last seek failed

  Status stored: none.
}

function sm_$dinit(unit: pinteger; ctlr: pinteger;
                   var num_blocks: integer32;
                   var sec_per_track: pinteger; var num_heads: pinteger;
                   out pvlabel_info: univ disk_$pvlabel_info_t;
                   out flags: pinteger): integer32;
  options(val_param);
label
  done;
var
  vtop_status: status_$t;
  rst_status: status_$t;
  status: integer32;
  start_failed: boolean;
  try: integer;
begin
  sm_$wire;
  sm_cb_ppn := mmu_$vtop(integer32(addr(sm_$cb)), vtop_status);
  if vtop_status.all <> 0 then
    crash_system(vtop_status);
%if long_iomap %then
  iomap[sm_iomap_cb] := sm_cb_ppn + sm_iomap_bias;
%else
  { the SAU3's and SAU4's entry (the TODO(sau) in cinit.pas) }
%endif
  ml_$lock(sm_dcte^.disk_error_que_hi);

  for try := 1 to 2 do begin
    sm_$reset(sm_dcte, rst_status);
    status := rst_status.all;
    if status <> 0 then
      goto done;
    sm_$cb.cmd_param := 2;
    sm_$cb.drive[unit].ready := true;
    start_failed := sm_$command(unit, sm_cmd_start) <> 0;
    if not start_failed then begin
      status := sm_$seek(unit, sm_dcte, 0, 0);
      if status = 0 then
        exit;
    end;
  end;
  if status <> 0 then
    goto done;

  if num_blocks <= 0 then begin
    sec_per_track := 18;
    num_heads := 19;
    num_blocks := 281466;
    pvlabel_info.l_00 := 16#22045E;
  end;

done:
  flags := 0;
  sm_$dinit := status;
  ml_$unlock(sm_dcte^.disk_error_que_hi);
end;
