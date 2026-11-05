{ win_$check_disk_status - read a unit's controller status and turn it into
  a disk status.

  Image addresses:
    sau2  0x00E19276  win_$check_disk_status (module-local)
    sau5  0x00E19708  win_$check_disk_status
    sau6  0x78019B74  win_$check_disk_status

  - The ANSI controller's form: the status word goes to WIN_$CSTAT; a
    completed command's error bits give the primary status, the general
    status (refined by win_$sense_general_status) the secondary.
  - Bit 3, or an unknown state, crashes the system.
  - The descriptor-list form (`win_descriptor_ctlr'): the status word
    and error code WIN_$INT saved are decoded.  WIN_$CNT counts each.

  Returns:
    status_$ok: no error
    the primary status: a completed command's error (seek, equipment
      check, data check, not ready, parity, DMA overrun)
    the secondary status: the drive's general status, or a failed
      report (the ANSI form)
    the error code's status: seek error, equipment check, invalid unit,
      drive time-out, not ready, ID-field ECC, data check (the
      descriptor-list form)
    status_$dma_not_at_end_of_range, status_$dma_overrun,
      status_$memory_parity_error_during_disk_write or
      status_$disk_controller_timeout: the status bits (that form)

  Status stored: none.
}

%if win_descriptor_ctlr %then
function win_$check_disk_status(unit: pinteger): integer32; internal;
var
  regs: win_$regs_ptr_t;
begin
  if (win_stat & 16#DCFF) = 16#0800 then
    win_$check_disk_status := status_$ok
  else begin
    regs := win_units[unit].regs;
    if (win_stat & 16#0400) <> 0 then begin
      { the controller's error code }
      case win_err of
        1, 5, 7, 8: begin
          win_$cnt.seek_errors := win_$cnt.seek_errors + 1;
          win_$check_disk_status := status_$disk_seek_error;
        end;
        2: begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          win_$check_disk_status := status_$disk_equipment_check;
        end;
        3: begin
          win_$check_disk_status := status_$invalid_unit_number;
        end;
        4: begin
          win_$cnt.w_10 := win_$cnt.w_10 + 1;
          win_$check_disk_status := status_$drive_timed_out;
        end;
        6: begin
          win_$cnt.not_ready := win_$cnt.not_ready + 1;
          win_$check_disk_status := status_$disk_not_ready;
        end;
        9: begin
          win_$cnt.data_checks := win_$cnt.data_checks + 1;
          win_$check_disk_status := status_$ecc_error_in_sector_id;
        end;
        10, 11: begin
          win_$cnt.data_checks := win_$cnt.data_checks + 1;
          win_$check_disk_status := status_$disk_data_check;
        end;
        12: begin
          { corrected data checks only }
          win_$cnt.data_checks := win_$cnt.data_checks + regs^.dc_count;
          regs^.dc_count := 0;
          win_$check_disk_status := status_$ok;
        end;
        13: begin
          { overruns only }
          win_$cnt.dma_overruns := win_$cnt.dma_overruns + regs^.ov_count;
          regs^.ov_count := 0;
          win_$check_disk_status := status_$ok;
        end;
        otherwise begin
          crash_system(status_$unknown_error_status_from_drive);
          win_$check_disk_status := status_$unknown_error_status_from_drive;
        end;
      end;
    end
    else if (win_stat & 16#0080) <> 0 then begin
      win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
      win_$check_disk_status := status_$dma_not_at_end_of_range;
    end
    else if (win_stat & 16#0040) <> 0 then begin
      win_$cnt.dma_overruns := win_$cnt.dma_overruns + 1;
      win_$check_disk_status := status_$dma_overrun;
    end
    else if (win_stat & 16#0020) <> 0 then
      win_$check_disk_status := status_$memory_parity_error_during_disk_write
    else if (win_stat & 16#101B) <> 0 then begin
      crash_system(status_$disk_driver_logic_error);
      win_$check_disk_status := status_$disk_driver_logic_error;
    end
    else if (win_stat & 16#0004) <> 0 then begin
      win_$cnt.w_0a := win_$cnt.w_0a + 1;
      win_$check_disk_status := status_$disk_controller_timeout;
    end
    else begin
      crash_system(status_$unknown_error_status_from_drive);
      win_$check_disk_status := status_$unknown_error_status_from_drive;
    end;
  end;
end;
%else

function win_$check_disk_status(unit: pinteger): integer32; internal;
label
  99;
var
  primary: integer32;
  secondary: integer32;
  regs: win_$regs_ptr_t;
  clear_cmd: pinteger;
  fallback: pinteger;
  out_byte: win_$byte_t;
  attn: win_$attn_t;
  stat: pinteger;
  cmd: pinteger;
begin
  fallback := 0;
  primary := status_$ok;
  win_$attn.gen := 0;
  regs := win_units[unit].regs;
  stat := regs^.status;
  win_$cstat := stat;

  { a completed command's error bits }
  if (stat & 16#800) <> 0 then begin
    regs^.go := 0;
    if (stat & 16#FA) <> 0 then
      if (stat & 8) <> 0 then
        crash_system(status_$disk_controller_error)
      else if (stat & 16#10) <> 0 then begin
        win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
        primary := status_$disk_equipment_check;
      end
      else if (stat & 2) <> 0 then
        primary := status_$memory_parity_error_during_disk_write
      else if (stat & 16#40) <> 0 then begin
        win_$cnt.dma_overruns := win_$cnt.dma_overruns + 1;
        primary := status_$dma_overrun;
      end
      else if (stat & 16#20) <> 0 then begin
        win_$cnt.data_checks := win_$cnt.data_checks + 1;
        primary := status_$disk_data_check;
      end
      else begin
        win_$cnt.not_ready := win_$cnt.not_ready + 1;
        primary := status_$disk_not_ready;
      end;
  end;

  { where the general status comes from }
  if (stat & 16#2000) <> 0 then begin
    secondary := win_$ansi_command(unit, 16#0F, chr(0), attn.gen);
    if secondary <> status_$ok then
      goto 99;
    fallback := 2;
  end
  else if (stat & 16#1000) <> 0 then
    attn.gen := regs^.command
  else begin
    secondary := status_$ok;
    goto 99;
  end;

  { record it, then refine }
  win_$attn := attn;
  secondary := win_$sense_general_status(unit, attn, clear_cmd);

  { the clearing command, its status ignored }
  cmd := clear_cmd;
  if cmd = 0 then
    cmd := fallback;
  if cmd <> 0 then
    discard(win_$ansi_command(unit, cmd, chr(0), out_byte));

  { the general status byte }
  if secondary = status_$ok then
    if (attn.gen & 2) <> 0 then begin
      discard(win_$ansi_command(unit, 1, chr(0), out_byte));
      win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
      secondary := status_$disk_equipment_check;
    end
    else if (attn.gen & 16#41) <> 0 then begin
      win_$cnt.not_ready := win_$cnt.not_ready + 1;
      secondary := status_$disk_not_ready;
    end
    else if (attn.gen & 16#4C) <> 0 then
      crash_system(status_$disk_driver_logic_error);

  { the primary status wins }
99:
  if primary <> status_$ok then
    win_$check_disk_status := primary
  else
    win_$check_disk_status := secondary;
end;
%endif
