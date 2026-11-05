{ SCSI_WAIT - wait for the drive's command to end, and turn its result
  into a status.

  Image addresses:
    sau7  0x3C484CE8  SCSI_WAIT
    sau9  0x3C47740C  SCSI_WAIT

  - After a reset (ct_scsi_reset) the reset's status is answered once,
    without a wait.
  - A command that ended has its status kept in ct_last_status; a
    command the drive answered with CHECK CONDITION gets the sense's
    status.
  - With ct_clear_on_ok set (a tape motion), the flag is cleared and a
    success ends the transfer state.  The command is no longer
    outstanding.

  Returns:
    0: the command ended well
    ct_reset_status: after a reset
    status_$ct_operation_in_progress: the drive was busy, or the command
      is still in progress
    ct_request_sense's result: CHECK CONDITION
    status_$ct_timeout_waiting_for_io: the command timed out
    status_$ct_unrecognized_controller_status: any other SCSI status or
      result
    status_$ct_controller_timeout: the time-out passed
    status_$ct_quit_waiting_for_io: a quit
    SCSI_$WAIT's status: it failed

  Status stored: none.
}

function scsi_wait(in timeout: integer32; in allow_quit: boolean): integer32;
label
  99;
var
  result: scsi_$result_t;
  st: status_$t;
  count: integer;
  n: integer;
begin
  if ct_reset_pending then begin
    st := ct_reset_status;
    ct_reset_pending := false;
    goto 99;
  end;
  n := scsi_$wait(ct_handle, timeout, false, ct_req_id, 1, result, count,
                  st);
  if st.all <> 0 then
    goto 99;
  case n of
    0: begin
        { An underrun is a short block, no error. }
        if (result.status.all <> 0)
           and then (result.status.all <> status_$scsi_dma_underrun) then
        begin
          if result.status.all = status_$scsi_command_in_progress then
            st.all := status_$ct_operation_in_progress
          else if result.status.all = status_$scsi_operation_timeout then
            st.all := status_$ct_timeout_waiting_for_io
          else
            st.all := status_$ct_unrecognized_controller_status;
          goto 99;
        end;
        if result.scsi_status = scsi_$st_good then
          st.all := 0
        else if result.scsi_status = scsi_$st_busy then
          st.all := status_$ct_operation_in_progress
        else if result.scsi_status = scsi_$st_check_condition then
          st.all := ct_request_sense
        else
          st.all := status_$ct_unrecognized_controller_status;
        ct_last_status := st;
      end;
    1: begin
      st.all := status_$ct_controller_timeout;
    end;
    2: begin
      st.all := status_$ct_quit_waiting_for_io;
    end;
  end;
  if ct_clear_on_ok then begin
    ct_clear_on_ok := false;
    if st.all = 0 then
      ct_io_state := ct_state_none;
  end;
99:
  scsi_wait := st.all;
  ct_busy := false;
end;
