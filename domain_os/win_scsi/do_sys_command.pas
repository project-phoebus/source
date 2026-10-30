{ WIN_SCSI_$DO_SYS_COMMAND - run a system device command for the SCSI
  driver.

  Image addresses:
    sau9  0x3C41C79E  WIN_SCSI_$DO_SYS_COMMAND

  - The SCSI driver passes a user's command for a disk this driver holds
    (SCSI_$SET_SYS_DEVICE): only MODE SENSE, INQUIRY and READ CAPACITY,
    at most 255 bytes, run under the controller's lock through a buffer
    of its own.
  - A CHECK CONDITION, when the caller gave a sense buffer, is followed
    by REQUEST SENSE (at most 255 bytes); its data are copied out instead
    of the command's, and sense_valid set, when it succeeds, a DMA
    overrun or underrun included.
  - result_status and scsi_status are the command's answer, stored
    however the command ended.

  Status stored:
    status_$ok: the command ran
    status_$scsi_illegal_sys_device_cmd: another command
    status_$io_controller_not_found: bus and target past controller 8
    status_$disk_controller_timeout: the command did not end
    status_$disk_driver_logic_error: no answer, another request's, or
      a failed REQUEST SENSE
    SCSI_$DO_COMMAND's or SCSI_$WAIT's status
}

procedure win_scsi_$do_sys_command(in bus: integer; in target: integer;
                                   in cdb: scsi_$cdb_t;
                                   var buf: univ win_scsi_sys_buf_t;
                                   in len: linteger; in dir: integer;
                                   out result_status: status_$t;
                                   out scsi_status: integer;
                                   var sense: univ win_scsi_sys_buf_t;
                                   in sense_len: linteger;
                                   out sense_valid: boolean;
                                   out status: status_$t);
var
  cnum: pinteger;
  u: win_scsi_unit_ptr_t;
  st: status_$t;
  lcdb: scsi_$cdb_t;
  lbuf: win_scsi_sys_buf_t;
  llen: linteger;
  ldir: integer;
  slen: linteger;
  valid: boolean;
  lun: integer;
  id: integer32;
  n: integer;
  count: integer;
  result: scsi_$result_t;
  rstat: status_$t;
  sstat: integer;
  i: integer;
begin
  status.all := status_$ok;
  sense_valid := false;
  case ord(cdb.b[0]) of
    win_scsi_op_mode_sense, win_scsi_op_inquiry, win_scsi_op_read_capacity:
      { empty };
    otherwise begin
      status.all := status_$scsi_illegal_sys_device_cmd;
      return;
    end;
  end;
  cnum := bus * 8 + target;
  if cnum > win_scsi_max_ctlr then begin
    status.all := status_$io_controller_not_found;
    return;
  end;

  st := status;
  lcdb := cdb;
  ldir := dir;
  llen := len;
  slen := sense_len;
  valid := sense_valid;
  lun := cdb.f.lun;
  u := addr(win_scsi_units[cnum]);
  ml_$lock(u^.lock);
  if llen > 255 then
    llen := 255;
  scsi_$do_command(u^.handle, lcdb, lbuf, llen, ldir, id, st);
  if st.all = status_$ok then begin
    n := scsi_$wait(u^.handle, win_scsi_timeout, false, id, 1, result,
                    count, st);
    if st.all = status_$ok then
      case n of
        0:
          if (result.id <> id) or else (count <> 1) then
            st.all := status_$disk_driver_logic_error
          else begin
            rstat := result.status;
            sstat := result.scsi_status;

            { The sense. }
            if (result.scsi_status = scsi_$st_check_condition)
               and then (addr(sense) <> nil) then begin
              for i := 0 to 5 do
                lcdb.b[i] := chr(0);
              lcdb.f.lun := lun;
              lcdb.f.op := win_scsi_op_request_sense;
              if slen > 255 then
                slen := 255;
              lcdb.b[4] := chr(slen);
              scsi_$do_command(u^.handle, lcdb, lbuf, slen, scsi_$dir_in,
                               id, st);
              if st.all = status_$ok then begin
                n := scsi_$wait(u^.handle, win_scsi_timeout, false, id, 1,
                                result, count, st);
                if (result.scsi_status <> scsi_$st_good)
                   or else (st.all <> status_$ok) or else (n <> 0) then
                  st.all := status_$disk_driver_logic_error
                else if (result.status.all = status_$scsi_dma_underrun)
                        or else (result.status.all = status_$ok)
                        or else (result.status.all = status_$scsi_dma_overrun)
                        then
                  valid := true
                else
                  st.all := status_$disk_driver_logic_error;
              end;
            end;
          end;
        1:
          st.all := status_$disk_controller_timeout;
        otherwise
          st.all := status_$disk_driver_logic_error;
      end;
  end;
  ml_$unlock(u^.lock);

  if valid then
    for i := 1 to slen do
      sense[i] := lbuf[i]
  else
    for i := 1 to llen do
      buf[i] := lbuf[i];
  status := st;
  sense_valid := valid;
  result_status := rstat;
  scsi_status := sstat;
end;
