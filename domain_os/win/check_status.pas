{ win_$check_status - read a command's completion byte, and the sense
  bytes of a failed command.

  Image addresses:
    sau8  0x03C1A13C  win_$check_status (module-local)

  - A completion byte with no error bit is success; with error bits but
    not bit 1 it counts as a data check of the drive and is success too.
  - A failed command's sense code gives the status and the drive's
    counter, and the count of sectors done before the failing one goes
    to win_count (zero when the sense names no sector); the completion
    byte of the sense command is then read.
  - The sense command not taken, or a sense code not known, crashes the
    system.

  Returns:
    status_$ok: the command succeeded, or its data were corrected
    status_$disk_seek_error, status_$disk_equipment_check,
      status_$disk_not_ready, status_$ecc_error_in_sector_id,
      status_$disk_data_check, status_$bad_disk_format,
      status_$invalid_disk_address: the sense code's
    status_$unknown_error_status_from_drive: a sense code not known
    status_$disk_controller_error: no completion byte, or the sense
      command not taken
    status_$disk_driver_logic_error: no sense bytes, or no completion
      byte after them

  Status stored: none.
}

function win_$check_status(unit: pinteger): integer32; internal;
var
  regs: win_$regs_ptr_t;
  ok: boolean;
  stat: win_$byte_t;
  first: integer;
  sense: win_$sense_t;
  i: integer;
  st: integer32;
begin
  regs := win_units[0].regs;
  ok := win_$wait_phase(win_phase_status) = status_$ok;
  if ok then begin
    stat := regs^.data;
    if (stat & 16#0E) = 0 then
      st := status_$ok
    else if (stat & 2) = 0 then begin
      win_stats[unit].stats.data_checks :=
        win_stats[unit].stats.data_checks + 1;
      st := status_$ok;
    end
    else begin
      { the sense bytes }
      win_cmd.unit := unit;
      first := win_cmd.sector;
      if win_$send_command(win_cmd_sense, 0, 0, 0) <> status_$ok then begin
        crash_system(status_$disk_controller_error);
        st := status_$disk_controller_error;
      end
      else begin
        ok := win_$wait_phase(win_phase_data_in) = status_$ok;
        if ok then begin
          for i := 1 to 2 do
            sense.w[i] := regs^.data_w;
          if sense.code <> 24 then
            if sense.valid = 0 then
              win_count := 0
            else
              win_count := sense.sector - first;

          case sense.code of
            1, 2, 6, 8, 21: begin
              st := status_$disk_seek_error;
              win_stats[unit].stats.seek_errors :=
                win_stats[unit].stats.seek_errors + 1;
            end;
            3, 23: begin
              st := status_$disk_equipment_check;
              win_stats[unit].stats.equip_checks :=
                win_stats[unit].stats.equip_checks + 1;
            end;
            4: begin
              st := status_$disk_not_ready;
              win_stats[unit].stats.not_ready :=
                win_stats[unit].stats.not_ready + 1;
            end;
            16, 20: begin
              st := status_$ecc_error_in_sector_id;
              win_stats[unit].stats.data_checks :=
                win_stats[unit].stats.data_checks + 1;
            end;
            17: begin
              st := status_$disk_data_check;
              win_stats[unit].stats.data_checks :=
                win_stats[unit].stats.data_checks + 1;
            end;
            18, 19, 25: begin
              st := status_$bad_disk_format;
              win_stats[unit].stats.equip_checks :=
                win_stats[unit].stats.equip_checks + 1;
            end;
            24: begin
              st := status_$ok;
              win_stats[unit].stats.data_checks :=
                win_stats[unit].stats.data_checks + 1;
            end;
            33, 35: begin
              st := status_$invalid_disk_address;
              win_stats[unit].stats.data_checks :=
                win_stats[unit].stats.data_checks + 1;
            end;
            otherwise begin
              crash_system(status_$unknown_error_status_from_drive);
              st := status_$unknown_error_status_from_drive;
            end;
          end;

          { the sense command's completion byte }
          ok := win_$wait_phase(win_phase_status) = status_$ok;
          if ok then
            stat := regs^.data
          else
            st := status_$disk_driver_logic_error;
        end
        else
          st := status_$disk_driver_logic_error;
      end;
    end;
  end
  else
    st := status_$disk_controller_error;
  win_$check_status := st;
end;
