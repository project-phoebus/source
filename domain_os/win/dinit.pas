{ WIN_$DINIT - the unit initialization entry.

  Image addresses:
    sau2  0x00E19CE8  WIN_$DINIT
    sau5  0x00E19EBC  WIN_$DINIT

  - Under the unit record's ML lock: the ANSI form runs DISK_INIT; the
    descriptor-list form (`win_descriptor_ctlr') restores the drive and
    reads its parameters (revision 3 and later) or sets them from the
    drive type, flags getting the type plus 16#300.

  Returns:
    disk_init's status: the ANSI form
    restore's or win_$command's status: the descriptor-list form
    status_$invalid_unit_number: a unit other than 0 or 1 (that form)
    status_$unrecognized_drive_id: no drive found (that form)

  Status stored: none.
}

%if win_descriptor_ctlr %then
function win_$dinit(unit: pinteger; ctlr: pinteger;
                    var num_blocks: integer32;
                    out sec_per_track: pinteger; var num_heads: pinteger;
                    var pvlabel_info: disk_$pvlabel_info_t;
                    out flags: pinteger): integer32;
  options(val_param);
label
  10, 20;
var
  rp: win_$regs_ptr_t;
  dp: ^win_$drive_t;
  status: integer32;
  dtype: integer;
  tries: integer;
begin
  if (unit < 0) or (unit > 1) then begin
    win_$dinit := status_$invalid_unit_number;
    return;
  end;

  with win_units[ctlr] do begin
    rp := regs;
    dp := addr(rp^.drives[unit]);
    ml_$lock(lock);
    win_cur_req := nil;
    rp^.config := win_config;
    rp^.go := 1;
    status := restore(ctlr, unit);

    if rp^.rev >= 3 then begin
      { the controller reads the drive's parameters }
      rp^.desc[1].drive := unit;
      rp^.count := 1;
      for tries := 1 to 6 do begin
        status := win_$command(ctlr, win_cmd_read_params);
        if status = status_$ok then
          exit;
      end;
      dtype := dp^.dtype;
      if (dtype = 0) or else (dtype = 15) then
        goto 10;
    end
    else begin
      { the drives the driver knows }
      dtype := dp^.dtype;
      dp^.spt := 8;
      dp^.w_06 := 10000;
      case dtype of
        1: begin
          dp^.cyls := 16#33E;
          dp^.heads := 6;
        end;
        2: begin
          dp^.cyls := 16#400;
          dp^.heads := 8;
        end;
        3: begin
          dp^.cyls := 16#2F2;
          dp^.heads := 16#B;
        end;
        4: begin
          dp^.cyls := 16#396;
          dp^.heads := 16#F;
        end;
        5: begin
          dp^.cyls := 16#4C8;
          dp^.heads := 16#F;
        end;
        6: begin
          dp^.cyls := 16#48E;
          dp^.heads := 7;
        end;
        otherwise begin
          if num_blocks <= 0 then
            goto 10;
        end;
      end;
    end;
    goto 20;

    { no drive, or one the driver does not know }
10: if status = status_$ok then
      status := status_$unrecognized_drive_id;

20: flags := dtype + 16#300;
    if num_blocks <= 0 then begin
      sec_per_track := dp^.spt;
      num_heads := dp^.heads;
      num_blocks := dp^.spt * (num_heads * dp^.cyls);
      pvlabel_info.l_00 := 16#002004CD;
      pvlabel_info.w_04 := dp^.w_06;
    end
    else if rp^.rev < 3 then
      dp^.w_06 := pvlabel_info.w_04;

    ml_$unlock(lock);
  end;
  win_$dinit := status;
end;
%else

function win_$dinit(unit: pinteger; ctlr: pinteger;
                    var num_blocks: integer32;
                    var sec_per_track: pinteger; var num_heads: pinteger;
                    out pvlabel_info: win_$geometry_t;
                    out flags: pinteger): integer32;
var
  status: integer32;
begin
  ml_$lock(win_units[ctlr].lock);

  status := disk_init(ctlr, unit, num_blocks, sec_per_track, num_heads,
                      pvlabel_info, flags);

  ml_$unlock(win_units[ctlr].lock);
  win_$dinit := status;
end;
%endif
