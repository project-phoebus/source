{ ct_request_sense - ask the drive for its sense and turn it into a
  status.

  Image addresses:
    sau9  0x3C4772B0  ct_request_sense (module-local)

  - Sends REQUEST SENSE (ct_sense_cdb, set up by CT_$ACQUIRE) into
    ct_sense and waits for it; SCSI_$DO_COMMAND's status is not tested.
  - A filemark, then the end of the medium, then the sense key give the
    status.
  - The status for a SCSI status other than good is replaced by the
    sense's.

  Returns:
    0: no sense, or a recovered error
    status_$ct_filemark_detected: the filemark bit
    status_$ct_end_of_tape: the end-of-medium bit, or a volume overflow
    the sense key's status: the other keys
    status_$ct_unrecognized_controller_status: any other key
    status_$ct_controller_timeout: SCSI_$WAIT timed out
    status_$ct_quit_waiting_for_io: SCSI_$WAIT saw a quit
    SCSI_$WAIT's status: it failed

  Status stored: none.
}

function ct_request_sense: integer32; internal;
var
  result: scsi_$result_t;
  st: status_$t;
  count: integer;
  n: integer;
begin
  scsi_$do_command(ct_handle, ct_sense_cdb, ct_sense, ct_sense_len,
                   scsi_$dir_in, ct_req_id, st);
  n := scsi_$wait(ct_handle, ct_scsi_timeout, false, ct_req_id, 1, result,
                  count, st);
  if n = 0 then begin
    if result.scsi_status <> scsi_$st_good then
      st.all := status_$ct_unrecognized_drive_status;
    if ct_sense.f.filemark then
      st.all := status_$ct_filemark_detected
    else if ct_sense.f.eom then
      st.all := status_$ct_end_of_tape
    else
      case ct_sense.f.key of
        ct_key_no_sense, ct_key_recovered_error:
          st.all := 0;
        ct_key_not_ready:
          st.all := status_$ct_unit_not_ready;
        ct_key_medium_error:
          st.all := status_$ct_marginal_block_detected;
        ct_key_hardware_error:
          st.all := status_$ct_controller_diag_failed;
        ct_key_illegal_request:
          st.all := status_$ct_illegal_drive_command;
        ct_key_unit_attention:
          st.all := status_$ct_tape_power_on_reset;
        ct_key_data_protect:
          st.all := status_$ct_tape_write_protected;
        ct_key_blank_check:
          st.all := status_$ct_read_no_data;
        ct_key_aborted_command:
          st.all := status_$ct_read_write_abort;
        ct_key_volume_overflow:
          st.all := status_$ct_end_of_tape;
        otherwise
          st.all := status_$ct_unrecognized_controller_status;
      end;
  end
  else if n = 1 then
    st.all := status_$ct_controller_timeout
  else if n = 2 then
    st.all := status_$ct_quit_waiting_for_io;
  ct_request_sense := st.all;
end;
