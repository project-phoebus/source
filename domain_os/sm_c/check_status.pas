{ sm_c_$check_status - turn a unit's status code into a disk status.

  Image addresses:
    sau3  0x00E6EF0A  sm_c_$check_status (module-local)
    sau4  0x0F87BD08  sm_c_$check_status (module-local)
    sau5  0x00E74A6E  sm_c_$check_status (module-local)
    sau6  0x7807B7BC  sm_c_$check_status (module-local)

  - Most codes are counted in the unit's counters; code 1 also clears the
    controller's command register.
  - A code of 1..37 the driver does not expect crashes the system; a
    code above 37 is status_$unknown_status_returned_by_hardware.

  Status stored: none.
}

function sm_c_$check_status(unit: integer): integer32; internal;
var
  code: integer;
begin
  with sm_$cb.c_unit[unit] do begin
    code := status.code;
    if code = 0 then begin
      sm_c_$check_status := 0;
      return;
    end;
    case code of
      22: begin
        stats.counts[1] := stats.counts[1] + 1;
        sm_c_$check_status := status_$disk_not_ready;
      end;
      6, 30: begin
        stats.counts[6] := stats.counts[6] + 1;
        sm_c_$check_status := status_$disk_data_check;
      end;
      19, 37: begin
        stats.counts[3] := stats.counts[3] + 1;
        sm_c_$check_status := status_$disk_seek_error;
      end;
      5, 18: begin
        stats.counts[5] := stats.counts[5] + 1;
        sm_c_$check_status := status_$drive_timed_out;
      end;
      13, 24, 25, 33: begin
        stats.counts[4] := stats.counts[4] + 1;
        sm_c_$check_status := status_$disk_equipment_check;
      end;
      4: begin
        stats.counts[4] := stats.counts[4] + 1;
        sm_c_$check_status := status_$disk_controller_timeout;
      end;
      20: begin
        sm_c_$check_status := status_$disk_write_protected;
      end;
      7, 10, 32: begin
        sm_c_$check_status := status_$invalid_disk_address;
      end;
      1: begin
        pbu_sm_c_page.cmd := sm_c_reg_clear;
        sm_c_$check_status := status_$disk_equipment_check;
      end;
      14: begin
        stats.counts[7] := stats.counts[7] + 1;
        sm_c_$check_status := status_$dma_overrun;
      end;
      2, 3, 8, 9, 11, 12, 15, 16, 17, 21, 23, 26, 27, 28, 29, 31, 34, 35,
      36: begin
        crash_system(status_$disk_driver_logic_error);
        sm_c_$check_status := status_$disk_driver_logic_error;
      end;
      otherwise begin
        sm_c_$check_status := status_$unknown_status_returned_by_hardware;
      end;
    end;
  end;
end;
