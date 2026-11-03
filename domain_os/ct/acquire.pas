%if ct_scsi %then
{ CT_$ACQUIRE - acquire the cartridge tape unit for the current
  process.

  Image addresses:
    sau9  0x3C477C7A  ct_scsi_open (nested)
    sau9  0x3C477E1C  CT_$ACQUIRE

  - Under the MT lock the current process becomes unit 0's owner; then
    the drive is set up on the SCSI bus (unless found absent before) and
    the module's code and data wired, the first time.
  - ct_scsi_open wires the sense and mode answers, ends an outstanding
    command with a reset, and asks where the tape is (once more after a
    power-on reset, buffered mode selected).  An error gives up the unit.
  - SCSI_$SETUP's status replaces IO_$GET_DCTE's; the early failures
    audit the status before it is set.

  Status stored:
    status_$ok: the unit was acquired
    status_$ct_tape_not_at_load_point: a warning, the tape is elsewhere
    status_$ct_invalid_unit_number: a unit other than 0
    status_$ct_unit_already_acquired: the current process holds it
    status_$ct_unit_in_use: another process holds it
    status_$ct_no_tape_controller: no DCTE, and no drive on the bus
    IO_$GET_DCTE's status, with the fail bit: no DCTE, and no drive
    SCSI_$SETUP's status: it failed
    status_$ct_drive_does_not_exist: the drive did not answer in time
    the callees' statuses: those failed
}

procedure ct_$acquire(in unit: integer; out status: status_$t);
label
  99;
var
  rel_st: status_$t;
  st: status_$t;
  audit_flags: pinteger;
  data_count: integer;
  set_up: boolean;

  { ct_scsi_open - prepare the drive for the new owner. }
  procedure ct_scsi_open;
  label
    10;
  var
    info: scsi_$info_t;
    retry: boolean;
    pos: integer32;
  begin
    scsi_$get_info(ct_handle, 8, info, status);
    if status.all <> 0 then
      goto 10;
    ct_max_xfer := info.max_transfer;
    ct_max_kb := ct_max_xfer div 1024;
    scsi_$wire(ct_handle, ct_sense, ct_scsi_wired_len, status);
    if status.all <> 0 then
      goto 10;
    ct_sense_cdb.t.op := ct_scsi_op_request_sense;
    ct_sense_cdb.t.lun := ct_lun;
    ct_sense_cdb.t.rest := 0;
    ct_sense_cdb.t.len := ct_sense_alloc;
    ct_sense_cdb.t.control := 0;
    if ct_busy then begin
      discard(ct_scsi_reset);
      status.all := scsi_wait(ct_scsi_timeout, false);
    end;
    if status.all <> 0 then
      goto 10;

    { Where is the tape?  A power-on reset is answered once more, with
      buffered mode selected. }
    retry := false;
    repeat
      status.all := ct_scsi_control(ct_op_block_address, 1);
      if status.all = 0 then begin
        status.all := scsi_wait(ct_scsi_timeout, true);
        case status.all of
          0: begin
              pos := ct_mode.h.addr;
              ct_dcte^.cstatus.all := 0;
              if pos <> 1 then
                status.all := status_$ct_tape_not_at_load_point;
              return;
            end;
          status_$ct_tape_power_on_reset: begin
              if not retry then begin
                ct_dcte^.cstatus.all := 0;
                ct_mode.select := ct_mode_buffered;
                discard(ct_scsi_control(ct_op_mode_select, 1));
                discard(scsi_wait(ct_scsi_timeout, false));
                status.all := 0;
              end;
              retry := not retry;
            end;
          status_$ct_timeout_waiting_for_io: begin
              ct_$release(0, false, status);
              if ct_scsi_state = ct_scsi_unknown then
                ct_scsi_state := ct_scsi_absent;
              status.all := status_$ct_drive_does_not_exist;
              retry := false;
            end;
        end;
      end;
    until not retry or else (status.all <> 0);
10:
    ct_owner := 0;
  end;

begin
  if unit = 0 then
    status.all := 0
  else begin
    status.all := status_$ct_invalid_unit_number;
    goto 99;
  end;
  ct_lun := 0;

  set_up := false;
  ml_$lock(ml_$mt_lock);
  if ct_owner = 0 then
    ct_owner := proc1_$current
  else if proc1_$current = ct_owner then
    status.all := status_$ct_unit_already_acquired
  else
    status.all := status_$ct_unit_in_use;
  ml_$unlock(ml_$mt_lock);
  if status.all <> 0 then
    goto 99;

  ct_dcte := io_$get_dcte(io_ctype_ctape, 0, status);
  if status.all <> 0 then
    if status.all = status_$io_controller_not_in_system then
      status.all := status_$ct_no_tape_controller
    else
      status.fail := true;
  if ct_scsi_state <> ct_scsi_absent then begin
    scsi_$setup(0, 0, ct_handle, st);
    if st.all = status_$scsi_bus_not_present then
      ct_scsi_state := ct_scsi_absent
    else begin
      ct_scsi_state := ct_scsi_present;
      status := st;
      if status.all = 0 then
        set_up := true;
    end;
  end;
  if status.all <> 0 then begin
    ct_owner := 0;
    goto 99;
  end;

  proc2_$set_cleanup(proc2_$cleanup_ct);
  if ct_area_count = 0 then begin
    mst_$wire_area(addr(ct_$proc_start), addr(ct_$proc_end),
                   ct_area_pages, 20, ct_area_count);
    mst_$wire_area(addr(ct_$data_start), addr(ct_$data_end),
                   ct_area_pages[ct_area_count + 1], 20 - ct_area_count,
                   data_count);
    ct_area_count := ct_area_count + data_count;
  end;
  if ct_scsi_state <> ct_scsi_absent then
    ct_scsi_open;

99:
  if (st.all <> 0) and then set_up then
    scsi_$release(ct_handle, rel_st);
  if audit_$enabled then begin
    if st.all <> 0 then
      audit_flags := 1
    else
      audit_flags := 0;
    audit_$log_event(audit_$acquire_ct_eu, audit_flags, st, 0, 0);
  end;
end;
%elseif ct_atbus_qic02 %then
{ CT_$ACQUIRE - acquire the cartridge tape unit for the current
  process.

  Image addresses:
    sau8  0x03C7AC08  CT_$ACQUIRE

  - With the AT bus adapter (`ct_atbus_qic02'): as the other form, and
    the adapter's PBU unit is set up for CT_$INT (PBU_$ACQUIRE_INT,
    sharing 3) with the CSR pages of the DCTE's request.
  - A command left outstanding is ended with a reset, which must give
    "tape power on/reset" within 480 ticks; otherwise the drive is taken
    as absent, the PBU unit and the ownership given up.
  - Under the controller's lock, with no transfer under way, the drive's
    status is read (DO_CTL_CMD's read status, 960 ticks with quit); a
    failure of the adapter resets it, once more on "tape power
    on/reset"; an unknown status, or the drive's absence, gives the PBU
    unit and the ownership up.  With a transfer under way the adapter is
    reset.
  - The early failures audit the status before it is set.

  Status stored:
    status_$ok: the unit was acquired (also "tape at load point", "write
      protected" and "tape power on/reset")
    status_$ct_tape_not_at_load_point: a warning, the status was read
    status_$ct_invalid_unit_number: a unit other than 0
    status_$ct_unit_already_acquired: the current process holds it
    status_$ct_unit_in_use: another process holds it
    status_$ct_no_tape_controller: the controller is not in the system
    status_$ct_drive_does_not_exist: the drive did not answer the reset
    status_$ct_tape_in_read_mode or status_$ct_tape_in_write_mode:
      warnings, a transfer is under way
    the callees' statuses, with the fail bit for IO_$GET_DCTE's: those
      failed
}

procedure ct_$acquire(in unit: integer; out status: status_$t);
label
  1, 8, 99;
type
  req_ptr_t = ^io_$acquire_rec_t;
var
  req: req_ptr_t;
  first: boolean;
  st: status_$t;
  audit_flags: pinteger;
  wired: integer;
  free_count: integer;
begin
  if unit = 0 then
    status.all := 0
  else begin
    status.all := status_$ct_invalid_unit_number;
    goto 99;
  end;
  ct_word_cfc := 2;

  ml_$lock(ml_$mt_lock);
  if ct_owner = 0 then
    ct_owner := proc1_$current
  else if proc1_$current = ct_owner then
    status.all := status_$ct_unit_already_acquired
  else
    status.all := status_$ct_unit_in_use;
  ml_$unlock(ml_$mt_lock);
  if status.all <> 0 then
    goto 99;

  ct_dcte := io_$get_dcte(io_ctype_ctape, 0, status);
  if status.all <> 0 then begin
    if status.all = status_$io_controller_not_in_system then
      status.all := status_$ct_no_tape_controller
    else
      status.fail := true;
    if status.all <> 0 then begin
      ct_owner := 0;
      goto 99;
    end;
  end;
  if ct_word_cfc = 2 then begin
    req := req_ptr_t(ct_dcte^.disk_dinit);
    first := true;
    pbu_$acquire_int(ct_pbu_unit, addr(ct_$int), ct_dcte,
                     univ_ptr(req^.csr.va), req^.csr.pa, req^.csr.pages, 3,
                     status);
  end;
  if status.all <> 0 then begin
    ct_owner := 0;
    goto 99;
  end;

  proc2_$set_cleanup(proc2_$cleanup_ct);
  if ct_area_count = 0 then begin
    mst_$wire_area(addr(ct_$proc_start), addr(ct_$proc_end),
                   ct_area_pages, 20, ct_area_count);
    free_count := 20 - ct_area_count;
    mst_$wire_area(addr(ct_$data_start), addr(ct_$data_end),
                   ct_area_pages[ct_area_count + 1], free_count, wired);
    ct_area_count := ct_area_count + wired;
  end;

  if ct_busy then begin
    reset_drive;
    st.all := ct_wait(480, false);
    if st.all <> status_$ct_tape_power_on_reset then begin
      st.all := status_$ct_drive_does_not_exist;
      pbu_$release_int(ct_pbu_unit, 3, status);
      ct_owner := 0;
      goto 8;
    end;
  end;
  ct_busy := false;

  ml_$lock(ct_dcte^.disk_error_que_hi);
1:
  case ct_state of
    ct_state_none: begin
        ct_reading := true;
        st.all := do_ctl_cmd(ct_cmd_read_status, ct_count_unlocked);
        if st.all = 0 then
          st.all := ct_wait(960, true);
        if st.all = 0 then
          st.all := status_$ct_tape_not_at_load_point
        else if st.all = status_$ct_tape_at_load_point then begin
          st.all := 0;
          ct_write_ok := true;
        end
        else if (st.all = status_$ct_tape_write_protected)
                or else (st.all = status_$ct_tape_power_on_reset) then
          st.all := 0
        else begin
          if (st.all = status_$ct_timeout_waiting_for_io)
             or else (st.all = status_$ct_controller_timeout)
             or else (st.all = status_$ct_illegal_drive_command)
             or else (st.all = status_$ct_illegal_controller_command)
          then begin
            reset_drive;
            st.all := ct_wait(480, false);
            if first and then (st.all = status_$ct_tape_power_on_reset)
            then begin
              first := false;
              goto 1;
            end;
            st.all := status_$ct_drive_does_not_exist;
          end;
          pbu_$release_int(ct_pbu_unit, 3, status);
          ct_owner := 0;
        end;
      end;
    ct_state_read: begin
        reset_drive;
        st.all := ct_wait(960, true);
        st.all := status_$ct_tape_in_read_mode;
      end;
    ct_state_write: begin
        reset_drive;
        st.all := ct_wait(960, true);
        st.all := status_$ct_tape_in_write_mode;
      end;
  end;
  ml_$unlock(ct_dcte^.disk_error_que_hi);
8:
  status := st;
  ct_total_2c := 0;
  ct_total_2e := 0;
  if status.code > 0 then
    ct_owner := 0;

99:
  if audit_$enabled then begin
    if st.all <> 0 then
      audit_flags := 1
    else
      audit_flags := 0;
    audit_$log_event(audit_$acquire_ct_eu, audit_flags, st, 0, 0);
  end;
end;
%else
{ CT_$ACQUIRE - acquire the cartridge tape unit for the current
  process.

  Image addresses:
    sau5  0x00E775BA  CT_$ACQUIRE

  - Under the MT lock the current process becomes unit 0's owner; the
    controller's DCTE is found, the CT cleanup bit set, and the first
    time the module's code and data wired.
  - Under the controller's lock, with no transfer under way, the tape is
    loaded (960 ticks' wait with quit).  An error gives the ownership up.
  - The early failures audit the status before it is set.

  Status stored:
    status_$ok: the unit was acquired (also "tape at load point" and
      "write protected")
    status_$ct_tape_not_at_load_point: a warning, the load succeeded
    status_$ct_invalid_unit_number: a unit other than 0
    status_$ct_unit_already_acquired: the current process holds it
    status_$ct_unit_in_use: another process holds it
    status_$ct_no_tape_controller: the controller is not in the system
    status_$ct_drive_does_not_exist: the load timed out or was illegal
    status_$ct_tape_in_read_mode or status_$ct_tape_in_write_mode:
      warnings, a transfer is under way
    the callees' statuses, with the fail bit for IO_$GET_DCTE's: those
      failed
}

procedure ct_$acquire(in unit: integer; out status: status_$t);
label
  99;
var
  st: status_$t;
  audit_flags: pinteger;
  data_count: integer;
begin
  if unit = 0 then
    status.all := 0
  else begin
    status.all := status_$ct_invalid_unit_number;
    goto 99;
  end;
  ct_word_cfc := 2;

  ml_$lock(ml_$mt_lock);
  if ct_owner = 0 then
    ct_owner := proc1_$current
  else if proc1_$current = ct_owner then
    status.all := status_$ct_unit_already_acquired
  else
    status.all := status_$ct_unit_in_use;
  ml_$unlock(ml_$mt_lock);
  if status.all <> 0 then
    goto 99;

  ct_dcte := io_$get_dcte(io_ctype_ctape, 0, status);
  if status.all <> 0 then begin
    if status.all = status_$io_controller_not_in_system then
      status.all := status_$ct_no_tape_controller
    else
      status.fail := true;
    if status.all <> 0 then begin
      ct_owner := 0;
      goto 99;
    end;
  end;

  proc2_$set_cleanup(proc2_$cleanup_ct);
  if ct_area_count = 0 then begin
    mst_$wire_area(addr(ct_$proc_start), addr(ct_$proc_end),
                   ct_area_pages, 20, ct_area_count);
    mst_$wire_area(addr(ct_$data_start), addr(ct_$data_end),
                   ct_area_pages[ct_area_count + 1], 20 - ct_area_count,
                   data_count);
    ct_area_count := ct_area_count + data_count;
  end;

  if ct_busy then begin
    status.all := do_ctl_cmd(ct_cmd_reset, 1);
    if status.all = 0 then
      status.all := ct_wait(8, true);
  end;

  ml_$lock(ct_dcte^.disk_error_que_hi);
  case ct_state of
    ct_state_none: begin
        ct_reading := true;
        st.all := do_ctl_cmd(ct_cmd_load, ct_count_unlocked);
        if st.all = 0 then
          st.all := ct_wait(960, true);
        if st.all = 0 then
          st.all := status_$ct_tape_not_at_load_point
        else if st.all = status_$ct_tape_at_load_point then begin
          st.all := 0;
          ct_write_ok := true;
        end
        else if st.all = status_$ct_tape_write_protected then
          st.all := 0
        else if (st.all = status_$ct_timeout_waiting_for_io)
                or else (st.all = status_$ct_controller_timeout)
                or else (st.all = status_$ct_illegal_drive_command)
                or else (st.all = status_$ct_illegal_controller_command)
        then begin
          reset_drive;
          st.all := status_$ct_drive_does_not_exist;
        end;
      end;
    ct_state_read: begin
      st.all := status_$ct_tape_in_read_mode;
    end;
    ct_state_write: begin
      st.all := status_$ct_tape_in_write_mode;
    end;
  end;
  ml_$unlock(ct_dcte^.disk_error_que_hi);
  status := st;
  ct_total_2c := 0;
  ct_total_2e := 0;
  if status.code > 0 then
    ct_owner := 0;

99:
  if audit_$enabled then begin
    if st.all <> 0 then
      audit_flags := 1
    else
      audit_flags := 0;
    audit_$log_event(audit_$acquire_ct_eu, audit_flags, st, 0, 0);
  end;
end;
%endif
