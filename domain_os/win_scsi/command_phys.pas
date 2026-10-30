{ win_scsi_command_phys - run a command on physical pages and wait for
  it.

  Image addresses:
    sau9  0x3C41B52E  win_scsi_command_phys

  - As win_scsi_command, through SCSI_$DO_COMMAND_PHYS, the transfer
    npages pages of len bytes; the answer's count is not checked.
}

function win_scsi_command_phys(handle: scsi_$handle_t;
                               lr: win_scsi_lun_ptr_t;
                               in cdb: scsi_$cdb_t; lun: integer;
                               dir: integer;
                               in pages: scsi_$phys_list_t;
                               npages: pinteger; len: pinteger;
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
  scsi_$do_command_phys(handle, cdb, pages, npages, len, dir, id, status);
  if status.all = status_$ok then begin
    n := scsi_$wait(handle, timeout, false, id, 1, result, count, status);
    status.all := win_scsi_check_result(handle, lr, lun, status.all, n,
                                        result);
    if status.all = status_$ok then
      if result.id <> id then
        status.all := status_$disk_driver_logic_error;
  end;
  win_scsi_command_phys := status.all;
end;
