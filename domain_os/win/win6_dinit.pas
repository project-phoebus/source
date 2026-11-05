{ WIN6_$DINIT - the unit initialization entry of the second board's
  controller.

  Image addresses:
    sau6  0x7801AE62  WIN6_$DINIT

  - Under the controller's lock: a command block (waiting up to 8 ticks
    for one) asks the controller for the drive's parameters, and the
    driver waits 20 ticks for the drive's eventcount.  From the answer
    the drive type (the flags word, 16#600 plus it), and for a label
    not yet known the geometry and the label information; the drive's
    record keeps the cylinder count.
  - Drive types other than 3, 4 and 7 are not recognized.

  Status stored:
    status_$ok: the drive's parameters were read
    status_$invalid_unit_number: unit is not 0 or 1
    status_$disk_controller_busy: no command block was free
    status_$disk_controller_timeout: no answer in 20 ticks
    win6_$epb_status's result: the controller failed the block
    status_$unrecognized_drive_id: another drive type
}

function win6_$dinit(unit: pinteger; ctlr: pinteger;
                     var num_blocks: integer32;
                     out sec_per_track: pinteger; var num_heads: pinteger;
                     var pvlabel_info: win6_$pvlabel_info_t;
                     out flags: pinteger): integer32;
label
  10, 20, 30;
var
  st: integer32;
  busy: boolean;
  free: boolean;
  first: integer;
  last: integer;
  idx: integer;
  deadline: integer32;
  wait_val: integer32;
  action: integer;
  info: win6_$drive_info_ptr_t;
begin
  if (unit < 0) or (unit > 1) then begin
    win6_$dinit := status_$invalid_unit_number;
    return;
  end;

  ml_$lock(win_units[ctlr].lock);

  { a command block, waiting 8 ticks for one }
  busy := win6_$get_iopbs(1, first, last) <> 0;
  idx := first;
  if busy then begin
    deadline := time_$clockh + 8;
    repeat
      free := win6_$get_iopbs(1, first, last) = 0;
      idx := first;
      if free then
        goto 10;
    until time_$clockh > deadline;
    st := status_$disk_controller_busy;
    goto 30;
  end;

  { the parameters block }
10:
  with win6_page^.iopbs[idx] do begin
    req := nil;
    status := -1;
    opu.op := win6_op_drive_params;
    opu.unused_72 := 0;
    opu.unit := unit;
    state := win6_state_used;
    f_0a.b_0a := 0;
    f_0a.b_0b := 0;
    l_10 := 0;
    phys := 0;
    buf := 0;
    l_1c := 0;
  end;
  win6_page^.init_b9 := win6_page^.init_b9 & 16#F2;
  win6_$send_iopb(idx);

  { the answer, or 20 ticks }
  wait_val := win6_drives[unit].ec.value + 1;
  if ec_$wait(addr(win6_drives[unit].ec),
              ec_$eventcount_ptr_t(addr(time_$clockh)),
              addr(ec_$nil_ec), wait_val, time_$clockh + 20, 0) = 0 then
    st := win6_$epb_status(win6_page^.iopbs[idx], action)
  else begin
    win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
    st := status_$disk_controller_timeout;
  end;
  if st <> status_$ok then
    goto 20;

  { the drive's parameters }
  info := addr(win6_page^.iopbs[idx].drive);
  flags := info^.dtype + 16#600;
  if not ((info^.dtype = 7) or else (info^.dtype = 4) or else
          (info^.dtype = 3)) then
    st := status_$unrecognized_drive_id;
  if num_blocks <= 0 then begin
    sec_per_track := info^.spt;
    num_heads := info^.heads;
    num_blocks := info^.cyls * num_heads * sec_per_track;
    pvlabel_info.w_08 := 1;
    pvlabel_info.w_04 := 0;
    if (info^.flags & 1) = 0 then begin
      pvlabel_info.w_00 := 16;
      pvlabel_info.w_02 := rshft(info^.b_0b, 2) * 2 + info^.b_02 + 1081;
    end
    else begin
      pvlabel_info.w_00 := 0;
      pvlabel_info.w_02 := rshft(info^.b_0b, 2) * 2 + info^.b_02 + 1076;
    end;
    if (info^.flags & 16#10) <> 0 then
      pvlabel_info.w_02 := pvlabel_info.w_02 + 6;
    if (info^.flags & 16#20) <> 0 then
      pvlabel_info.w_02 := pvlabel_info.w_02 + 6;
  end;
  with win6_drives[unit] do begin
    geom.cyls := info^.cyls;
    geom.b_02 := 0;
    geom.b_03 := 0;
  end;

20:
  win6_$rtn_iopbs(1, idx, last);
30:
  ml_$unlock(win_units[ctlr].lock);
  win6_$dinit := st;
end;
