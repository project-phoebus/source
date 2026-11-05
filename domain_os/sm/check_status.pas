{ sm_$check_status - turn a drive's command status into a disk status.

  Image addresses:
    sau3  0x00E6DCB8  sm_$check_status (module-local)
    sau4  0x0F877434  sm_$check_status (module-local)
    sau5  0x00E6F010  sm_$check_status (module-local)
    sau6  0x780764A8  sm_$check_status (module-local)

  - With an error block (status bit 6) the drive's error block is read
    with the sense command, the command block's words saved around it,
    and each error found is counted in the drive's counters.
  - A driver logic error in the error word crashes the system.  The
    error byte's data check, seek error and equipment bits are tested
    last, the last one found winning.

  Returns:
    0: the drive's status has state 0, or lacks bit 6
    status_$unknown_error_status_from_drive: the status lacks bit 7
    a disk status (not ready, timed out, equipment check, write
      protected, data check, seek error): the error block's
    sm_$command's status: the sense command's, the block naming none

  Status stored: none.
}

function sm_$check_status(unit: integer): integer32; internal;
var
  result_status: integer32;
  saved_status: sm_$status_t;
  saved_cmd: sm_$byte_t;
  saved_unit: 0..3;
  saved_offset: pinteger;
begin
  if sm_$cb.drive[unit].status.state = 0 then begin
    sm_$check_status := 0;
    return;
  end;
  if not (7 in sm_$cb.drive[unit].status.bits) then begin
    sm_$check_status := status_$unknown_error_status_from_drive;
    return;
  end;

  { read the drive's error block }
  saved_status := sm_$cb.drive[unit].status;
  saved_cmd := sm_$cb.cmd_word.cmd;
  saved_unit := sm_$cb.cmd_word.unit;
  saved_offset := sm_$cb.buf_offset;
  sm_$cb.buf_offset :=
    sm_$page_offset(addr(sm_$cb.drive[unit].err_block));
  result_status := sm_$command(unit, sm_cmd_sense);
  sm_$cb.drive[unit].status := saved_status;
  sm_$cb.cmd_word.cmd := saved_cmd;
  sm_$cb.cmd_word.unit := saved_unit;
  sm_$cb.buf_offset := saved_offset;

  with sm_$cb.drive[unit] do begin
    if 6 in status.bits then
      if err_block.err * [6, 7, 8, 11, 13] <> [] then
        crash_system(status_$disk_driver_logic_error)
      else if err_block.err * [3, 4, 5, 9, 10] <> [] then begin
        stats.counts[4] := stats.counts[4] + 1;
        result_status := status_$disk_equipment_check;
      end
      else if 14 in err_block.err then begin
        stats.counts[1] := stats.counts[1] + 1;
        sm_$check_status := status_$disk_not_ready;
        return;
      end
      else if 12 in err_block.err then begin
        stats.counts[5] := stats.counts[5] + 1;
        sm_$check_status := status_$drive_timed_out;
        return;
      end
      else if 15 in err_block.err then
        result_status := status_$disk_write_protected;

    if (err_block.err2 & 16#18) <> 0 then begin
      stats.counts[6] := stats.counts[6] + 1;
      result_status := status_$disk_data_check;
    end;
    if (err_block.err2 & 16#C0) <> 0 then begin
      stats.counts[3] := stats.counts[3] + 1;
      result_status := status_$disk_seek_error;
    end;
    if (err_block.err2 & 16#20) <> 0 then begin
      stats.counts[4] := stats.counts[4] + 1;
      result_status := status_$disk_equipment_check;
    end;

    if 6 in status.bits then
      sm_$check_status := result_status
    else
      sm_$check_status := 0;
  end;
end;
