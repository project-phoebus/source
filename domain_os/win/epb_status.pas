{ win6_$epb_status - the status of an error block, and the action it
  asks for.

  Image addresses:
    sau6  0x7801A634  win6_$epb_status (module-local)

  - Severity none: status 0, no action; a rejected block: -1, a retry.
  - Otherwise the class and the code give the status and the action,
    and bump a WIN_$CNT counter; the block is counted in WIN6_$ERRORS
    and copied to the next of WIN6_$EPBS's entries (a ring of 64).  A
    recovered error answers 0, no action.
  - A code the class does not know is the hardware's unknown status,
    and a controller-class error the drive's unknown error status: both
    go to CRASH_SYSTEM.

  Status stored: none.
}

function win6_$epb_status(in epb: win6_$iopb_t; out action: integer):
  integer32;
  internal;
var
  status: integer32;
  crash_status: integer32;
begin
  case epb.err.sev of
    win6_sev_none: begin
      win6_$epb_status := 0;
      action := win6_act_none;
      return;
    end;
    win6_sev_rejected: begin
      win6_$epb_status := -1;
      action := win6_act_retry;
      return;
    end;
  end;

  case epb.err.class of
    win6_class_command: begin
      action := win6_act_none;
      case epb.err.code of
        1, 2, 6, 7: begin
          status := status_$disk_driver_logic_error;
        end;
        3, 4, 5: begin
          status := status_$invalid_disk_address;
        end;
        otherwise begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          status := status_$unknown_status_returned_by_hardware;
        end;
      end;
    end;
    win6_class_drive: begin
      action := win6_act_retry;
      case epb.err.code of
        31, 26, 32, 9: begin
          win_$cnt.not_ready := win_$cnt.not_ready + 1;
          status := status_$disk_not_ready;
          action := win6_act_none;
        end;
        35, 46, 12, 7, 5, 4, 3, 2, 1: begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          status := status_$disk_controller_timeout;
        end;
        45, 40, 39, 37, 13, 22, 21, 23, 36, 19, 18, 10, 8, 6: begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          status := status_$disk_controller_error;
        end;
        34, 30, 29, 47, 27: begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          status := status_$disk_equipment_check;
        end;
        25, 24: begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          status := status_$disk_write_protected;
          action := win6_act_none;
        end;
        44, 38, 20, 14: begin
          win_$cnt.data_checks := win_$cnt.data_checks + 1;
          status := status_$disk_data_check;
          case epb.err.code of
            14: begin
              action := win6_act_ecc;
            end;
            20, 38: begin
              action := win6_act_retry;
            end;
          end;
        end;
        17: begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          status := status_$disk_controller_error;
        end;
        16, 15, 28: begin
          win_$cnt.seek_errors := win_$cnt.seek_errors + 1;
          status := status_$disk_seek_error;
        end;
        43, 42, 41, 11: begin
          win_$cnt.w_10 := win_$cnt.w_10 + 1;
          status := status_$drive_timed_out;
        end;
        33: begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          status := status_$unknown_error_status_from_drive;
        end;
        otherwise begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          status := status_$unknown_status_returned_by_hardware;
        end;
      end;
    end;
    win6_class_ctlr: begin
      action := win6_act_none;
      status := status_$unknown_error_status_from_drive;
      crash_status := status;
      crash_system(crash_status);
    end;
    win6_class_bus: begin
      action := win6_act_retry;
      case epb.err.code of
        1, 2, 3: begin
          status := status_$bus_error_occurred_during_disk_dma_transfer;
          action := win6_act_none;
        end;
        4: begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          status := status_$disk_dc_powerfail;
        end;
        5: begin
          win_$cnt.dma_overruns := win_$cnt.dma_overruns + 1;
          status := status_$dma_overrun;
        end;
        6: begin
          status := status_$dma_not_at_end_of_range;
        end;
        7: begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          status := status_$disk_controller_timeout;
        end;
        otherwise begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          status := status_$unknown_status_returned_by_hardware;
        end;
      end;
    end;
    win6_class_board: begin
      action := win6_act_retry;
      if epb.err.code = 1 then begin
        win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
        status := status_$disk_controller_error;
      end
      else begin
        win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
        status := status_$unknown_status_returned_by_hardware;
      end;
    end;
    otherwise begin
      win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
      status := status_$unknown_status_returned_by_hardware;
    end;
  end;

  { the count by severity, class and code }
  if status = status_$unknown_status_returned_by_hardware then begin
    crash_status := status;
    crash_system(crash_status);
  end
  else
    with win6_$errors[epb.err.sev] do
      case epb.err.class of
        win6_class_command: begin
          c0[epb.err.code] := c0[epb.err.code] + 1;
        end;
        win6_class_drive: begin
          c1[epb.err.code] := c1[epb.err.code] + 1;
        end;
        win6_class_ctlr: begin
          c2[epb.err.code] := c2[epb.err.code] + 1;
        end;
        win6_class_bus: begin
          c3[epb.err.code] := c3[epb.err.code] + 1;
        end;
        win6_class_board: begin
          c4[epb.err.code] := c4[epb.err.code] + 1;
        end;
      end;

  { the copy in the log }
  if win6_$epbx = win6_epbs_size then
    win6_$epbx := 1
  else
    win6_$epbx := win6_$epbx + 1;
  win6_$epbs[win6_$epbx] := epb;

  if epb.err.sev = win6_sev_recovered then begin
    status := 0;
    action := win6_act_none;
  end;
  win6_$epb_status := status;
end;
