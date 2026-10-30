{ win_scsi_command - run a command on a buffer and wait for it.

  Image addresses:
    sau9  0x3C41B468  win_scsi_command

  - Clears the logical unit's sense flags, starts the command
    (SCSI_$DO_COMMAND), waits up to timeout for its one answer and
    checks it (win_scsi_check_result).
  - Returns the status: SCSI_$DO_COMMAND's, the check's, or
    status_$disk_driver_logic_error when the answer is another
    request's or not one.
}

function win_scsi_command(handle: scsi_$handle_t; lr: win_scsi_lun_ptr_t;
                          in cdb: scsi_$cdb_t; lun: integer; dir: integer;
                          buf: univ_ptr; len: integer32;
                          timeout: integer32): integer32; internal;
var
  status: status_$t;
  id: integer32;
  result: scsi_$result_t;
  n: integer;
  count: integer;
begin
  lr^.valid := false;
  lr^.recovered := false;
  scsi_$do_command(handle, cdb, win_scsi_data_ptr_t(buf)^, len, dir, id,
                   status);
  if status.all = status_$ok then begin
    n := scsi_$wait(handle, timeout, false, id, 1, result, count, status);
    status.all := win_scsi_check_result(handle, lr, lun, status.all, n,
                                        result);
    if status.all = status_$ok then begin
      if result.id <> id then
        status.all := status_$disk_driver_logic_error;
      if count <> 1 then
        status.all := status_$disk_driver_logic_error;
    end;
  end;
  win_scsi_command := status.all;
end;
