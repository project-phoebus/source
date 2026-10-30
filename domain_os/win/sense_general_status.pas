{ win_$sense_general_status - turn the drive's general status byte into a
  disk status, reading the report registers it points at.

  Image addresses:
    sau2  0x00E19186  win_$sense_general_status (module-local)

  - Bit 4 asks for report 16#0E (clearing command 1), bit 5 for report
    16#0D (clearing command 2), into WIN_$SENSE; the first report's
    status wins.  The clearing command goes into clear_cmd.

  Returns:
    status_$ok: neither bit, or no error in the reports
    status_$disk_seek_error, status_$disk_write_protected or
      status_$disk_equipment_check: the first report's bits
    status_$disk_not_ready: the second report's bit 1 and the drive's
      bit 0
    status_$unknown_error_status_from_drive: an unknown report
    an ANSI command's status: a report could not be read

  Status stored: none.
}

function win_$sense_general_status(unit: pinteger;
                                   general_status: win_$attn_t;
                                   out clear_cmd: pinteger): integer32;
  internal;
var
  first: integer32;
  status: integer32;
  in_param: pinteger;                     { never written }
begin
  { nothing to clear }
  if (general_status.gen & 16#30) = 0 then begin
    win_$sense_general_status := status_$ok;
    clear_cmd := 0;
    return;
  end;

  win_$sense.w := 0;
  first := status_$ok;

  { report 16#0E }
  if (general_status.gen & 16#10) <> 0 then begin
    clear_cmd := 1;
    first := win_$ansi_command(unit, 16#0E, in_param, win_$sense.b0);
    if first = status_$ok then
      if (win_$sense.b0 & 1) <> 0 then begin
        win_$cnt.seek_errors := win_$cnt.seek_errors + 1;
        first := status_$disk_seek_error;
      end
      else if (win_$sense.b0 & 8) <> 0 then
        first := status_$disk_write_protected
      else if (win_$sense.b0 & 16#36) <> 0 then begin
        win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
        first := status_$disk_equipment_check;
      end
      else
        first := status_$unknown_error_status_from_drive;
  end;

  { report 16#0D }
  status := status_$ok;
  if (general_status.gen & 16#20) <> 0 then begin
    clear_cmd := 2;
    status := win_$ansi_command(unit, 16#0D, in_param, win_$sense.b1);
    if status = status_$ok then
      if ((win_$sense.b1 & 2) <> 0) and then
         ((general_status.gen & 1) <> 0) then
        status := status_$disk_not_ready
      else if (win_$sense.b1 & 1) = 0 then
        status := status_$unknown_error_status_from_drive;
  end;

  { the first status wins }
  if first <> status_$ok then
    status := first;
  win_$sense_general_status := status;
end;
