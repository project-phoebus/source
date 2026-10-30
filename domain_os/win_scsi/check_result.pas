{ win_scsi_check_result - turn a command's wait into a disk status.

  Image addresses:
    sau9  0x3C41B3A0  win_scsi_check_result

  - wait_status and n are SCSI_$WAIT's status and result, result its
    answer: a failed wait passes its status on, no answer is
    status_$disk_controller_timeout, more than one a logic error, and a
    failed command its status.
  - Of the SCSI status, CHECK CONDITION asks for the sense
    (win_scsi_request_sense), BUSY is status_$drive_timed_out, any other
    but GOOD a logic error.
}

function win_scsi_check_result(handle: scsi_$handle_t;
                               lr: win_scsi_lun_ptr_t; lun: integer;
                               wait_status: integer32; n: integer;
                               in result: scsi_$result_t): integer32;
  internal;
var
  sense: boolean;
  st: integer32;
begin
  sense := false;
  win_scsi_check_result := status_$ok;
  st := wait_status;
  if st <> status_$ok then begin
    win_scsi_check_result := st;
    return;
  end;
  case n of
    0: { empty };
    1: begin
      win_scsi_check_result := status_$disk_controller_timeout;
      return;
    end;
    otherwise begin
      win_scsi_check_result := status_$disk_driver_logic_error;
      return;
    end;
  end;
  st := result.status.all;
  if st <> status_$ok then begin
    win_scsi_check_result := st;
    return;
  end;

  case result.scsi_status of
    scsi_$st_good:
      return;
    scsi_$st_check_condition:
      sense := true;
    scsi_$st_busy:
      st := status_$drive_timed_out;
    otherwise
      st := status_$disk_driver_logic_error;
  end;
  if sense and then (st = status_$ok) then
    st := win_scsi_request_sense(handle, lr, lun);
  win_scsi_check_result := st;
end;
