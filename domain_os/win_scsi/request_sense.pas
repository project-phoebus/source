{ win_scsi_request_sense - ask a unit for its sense and turn it into a
  disk status.

  Image addresses:
    sau9  0x3C41B17C  win_scsi_request_sense

  - Sends REQUEST SENSE for 18 bytes; a failed command, wait or SCSI
    status answers status_$disk_driver_logic_error.
  - Logs the sense key, the additional sense code, the valid bit and the
    information bytes in the module's ten-entry log, keeps the
    information in the logical unit when it is valid, and counts the
    error in the unit's statistics.
  - Returns the disk status of the sense key (the additional sense code
    refines a recovered error, a hardware error and a unit attention);
    an answer in neither the extended format nor error code 0 is
    status_$unknown_status_returned_by_hardware.
}

function win_scsi_request_sense(handle: scsi_$handle_t;
                                lr: win_scsi_lun_ptr_t;
                                lun: integer): integer32; internal;
var
  i: integer;
  cdb: scsi_$cdb_t;
  sense: win_scsi_sense_t;
  result: scsi_$result_t;
  status: status_$t;
  id: integer32;
  count: integer;
  n: integer;
  sense_key: integer;
  code: integer;
begin
  lr^.valid := false;
  lr^.recovered := false;

  { REQUEST SENSE. }
  for i := 0 to 5 do
    cdb.b[i] := chr(0);
  cdb.f.lun := lun;
  cdb.f.op := win_scsi_op_request_sense;
  cdb.b[4] := chr(18);
  scsi_$do_command(handle, cdb, sense, ord(cdb.b[4]), scsi_$dir_in, id,
                   status);
  if status.all <> status_$ok then begin
    win_scsi_request_sense := status_$disk_driver_logic_error;
    return;
  end;
  n := scsi_$wait(handle, win_scsi_timeout, false, id, 1, result, count,
                  status);
  if (status.all <> status_$ok) or else (n <> 0)
     or else (result.status.all <> status_$ok)
     or else (result.scsi_status <> scsi_$st_good) then begin
    win_scsi_request_sense := status_$disk_driver_logic_error;
    return;
  end;

  lr^.valid := sense.f.valid;
  if (sense.f.err_class <> win_scsi_extended_sense)
     and then (sense.f.err_code <> 0) then begin
    win_scsi_request_sense := status_$unknown_status_returned_by_hardware;
    return;
  end;

  { The log. }
  sense_key := sense.f.key;
  code := ord(sense.b[12]);
  with win_scsi_log[win_scsi_log_index] do begin
    key := sense_key;
    asc := code;
    valid := sense.f.valid;
    info := sense.info;
  end;
  win_scsi_log_index := win_scsi_log_index + 1;
  if win_scsi_log_index > 10 then
    win_scsi_log_index := 1;
  if lr^.valid then
    lr^.info := sense.info;

  { The status. }
  case sense_key of
    win_scsi_key_recovered_error: begin
      lr^.stats.data_checks := lr^.stats.data_checks + 1;
      lr^.recovered := true;
      case code of
        win_scsi_asc_recovered_with_ecc:
          win_scsi_request_sense := status_$disk_ok_after_crc_correction;
        win_scsi_asc_unrecovered_read_error,
        win_scsi_asc_recovered_with_retries:
          win_scsi_request_sense := status_$disk_ok_after_retry;
        otherwise
          win_scsi_request_sense := status_$disk_ok_after_device_recovery;
      end;
    end;
    win_scsi_key_medium_error: begin
      win_scsi_request_sense := status_$disk_data_check;
      lr^.stats.data_checks := lr^.stats.data_checks + 1;
    end;
    win_scsi_key_hardware_error: begin
      if (code = win_scsi_asc_no_seek_complete)
         or else (code = win_scsi_asc_positioning_error) then begin
        lr^.stats.seek_errors := lr^.stats.seek_errors + 1;
        win_scsi_request_sense := status_$disk_seek_error;
      end
      else begin
        lr^.stats.equip_checks := lr^.stats.equip_checks + 1;
        win_scsi_request_sense := status_$disk_equipment_check;
      end;
    end;
    win_scsi_key_not_ready: begin
      lr^.stats.not_ready := lr^.stats.not_ready + 1;
      win_scsi_request_sense := status_$disk_not_ready;
    end;
    win_scsi_key_data_protect: begin
      win_scsi_request_sense := status_$disk_write_protected;
    end;
    win_scsi_key_blank_check: begin
      win_scsi_request_sense := status_$bad_disk_format;
    end;
    win_scsi_key_vendor_unique: begin
      win_scsi_request_sense := status_$unknown_status_returned_by_hardware;
    end;
    win_scsi_key_illegal_request: begin
      win_scsi_request_sense := status_$disk_illegal_request_for_device;
    end;
    win_scsi_key_unit_attention: begin
      if code = win_scsi_asc_medium_changed then
        win_scsi_request_sense := status_$storage_module_stopped
      else
        win_scsi_request_sense := status_$disk_unit_attention;
    end;
    otherwise begin
      win_scsi_request_sense := status_$disk_driver_logic_error;
    end;
  end;
end;
