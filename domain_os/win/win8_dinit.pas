{ WIN8_$DINIT - the unit initialization entry.

  Image addresses:
    sau8  0x03C1AB00  WIN8_$DINIT

  - Under the controller's ML lock.  The drive type is the low four
    bits of the controller's select port.  Types 3, 4, 7 and 12 have a
    controller that reports the drive's parameters (and a 256- or
    512-byte sector); the others' cylinders and heads are known here and
    given to the controller, with 9 sectors a track.
  - With num_blocks 0 or less the geometry and the label information
    are returned.
  - A drive 1 that is not ready is no unit: its not-ready count is taken
    back.

  Returns:
    status_$ok: the drive is up
    status_$invalid_unit_number: a unit other than 0 or 1, or drive 1 not
      ready
    status_$unrecognized_drive_id: a drive type not known, or a reported
      drive of more than 400000 blocks
    status_$disk_controller_error: no parameter phase
    win_$send_command's or win_$check_status's result: a command failed

  Status stored: none.
}

function win8_$dinit(unit: pinteger; ctlr: pinteger;
                     var num_blocks: integer32;
                     out sec_per_track: pinteger; out num_heads: pinteger;
                     out pvlabel_info: win_$pvlabel_t;
                     out flags: pinteger): integer32;
  options(val_param);
var
  dcte: win_$dcte_ptr_t;
  regs: win_$regs_ptr_t;
  precomp: integer;
  dtype: integer;
  cyls: integer;
  heads: pinteger;
  spt: pinteger;
  status: integer32;
  failed: boolean;
  params: win_$params_t;
  total: linteger;
  i: integer;
begin
  if (unit <> 0) and (unit <> 1) then begin
    win8_$dinit := status_$invalid_unit_number;
    return;
  end;

  win_page_pmape := mmu_$get_pmape_addr(addr(win_page));
  win_params_reported := false;
  dcte := win_units[ctlr].dcte;
  regs := win_units[ctlr].regs;
  ml_$lock(dcte^.lock);

  { the drive type }
  precomp := 16#7FF;
  dtype := regs^.select & 16#0F;
  flags := dtype + 16#400;
  spt := 9;
  case dtype of
    1: begin
      heads := 5;
      cyls := 987;
    end;
    2: begin
      heads := 7;
      cyls := 1166;
    end;
    3, 4, 7: begin
      win_params_reported := true;
      flags := flags + 16#100;
    end;
    5: begin
      heads := 5;
      cyls := 1024;
    end;
    6: begin
      heads := 8;
      cyls := 1024;
    end;
    10: begin
      heads := 6;
      cyls := 830;
    end;
    11: begin
      heads := 15;
      cyls := 1224;
    end;
    12: begin
      win_params_reported := true;
      flags := flags + 16#200;
      pvlabel_info.w_08 := 1;
    end;
    otherwise begin
      win8_$dinit := status_$unrecognized_drive_id;
      ml_$unlock(dcte^.lock);
      return;
    end;
  end;

  win_cmd.count := 1;
  win_cmd.ctl_7 := false;
  win_cmd.ctl_6 := false;
  win_cmd.unit := unit;
  if win_params_reported then begin
    { the controller reports the drive }
    win_max_count := 31;
    status := win_$send_command(win_cmd_test_ready, 0, 0, 0);
    if status = status_$ok then begin
      status := win_$check_status(unit);
      if status = status_$ok then begin
        status := win_$send_command(win_cmd_drive_params, 0, 0, 0);
        if status = status_$ok then begin
          failed := win_$wait_phase(win_phase_data_in) <> status_$ok;
          if failed then
            status := status_$disk_controller_error
          else begin
            for i := 1 to 5 do
              params.w[i] := regs^.data_w;
            status := win_$check_status(unit);
            if status = status_$ok then begin
              cyls := params.cyls + 1;
              heads := params.heads + 1;
              spt := rshft(params.rwc, 8) + 1;
              if params.w_04 < 0 then
                win_sector_size := 512
              else
                win_sector_size := 256;
            end;
          end;
        end;
      end;
    end;
  end
  else begin
    { the drive given to the controller }
    win_max_count := 7;
    status := win_$send_command(win_cmd_init_drive, 0, 0, 0);
    if status = status_$ok then begin
      params.cyls := cyls;
      params.heads := heads;
      params.rwc := 0;
      params.precomp := precomp;
      params.ecc := 0;
      failed := win_$wait_phase(win_phase_data_out) <> status_$ok;
      if failed then
        status := status_$disk_controller_error
      else begin
        for i := 1 to 4 do
          regs^.data_w := params.w[i];
        status := win_$check_status(unit);
      end;
      if status = status_$ok then begin
        status := win_$send_command(win_cmd_test_ready, 0, 0, 0);
        if status = status_$ok then
          status := win_$check_status(unit);
      end;
    end;
  end;

  { the geometry }
  total := spt * (cyls * heads);
  if win_params_reported then begin
    if total > 400000 then begin
      win8_$dinit := status_$unrecognized_drive_id;
      ml_$unlock(dcte^.lock);
      return;
    end;
    if total < 185000 then
      flags := 16#507
    else if (params.b[5] & 2) <> 0 then
      flags := 16#60C
    else
      flags := 16#504;
  end;
  if num_blocks <= 0 then begin
    num_blocks := total;
    pvlabel_info.w_04 := precomp;
    sec_per_track := spt;
    num_heads := heads;
    if win_params_reported then begin
      if (params.b[5] & 2) <> 0 then
        pvlabel_info.w_02 := params.b[7] * 2 + params.b[8] + 16#437
      else
        pvlabel_info.w_02 := params.b[7] + params.b[8] + params.b[9] +
                             16#43B;
      pvlabel_info.w_00 := params.b[6];
    end
    else
      pvlabel_info.l_00 := 16#000C045A;
  end;
  ml_$unlock(dcte^.lock);

  if (status = status_$disk_not_ready) and (unit <> 0) then begin
    win8_$dinit := status_$invalid_unit_number;
    win_stats[unit].stats.not_ready := win_stats[unit].stats.not_ready - 1;
  end
  else
    win8_$dinit := status;
end;
