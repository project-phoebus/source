{ WIN7_$ERROR_QUE - the error queue entry: the failed blocks of the
  current process's requests on a drive.

  Image addresses:
    sau7  0x3C41C256  WIN7_$ERROR_QUE

  - Under the controller's ML lock.  A time-out (is_timeout 1) crashes
    the system.
  - Each failed block of the drive and the current process gives its
    requests a status from its completion code and the controller's
    status and error bytes, counted in the drive's statistics; a
    transfer's sectors done keep status_$ok, the rest get the status and
    are taken off the read or write count.  The block goes back to the
    free list under the spin lock.
  - When one was found, the process's eventcount is advanced.
  - result is not stored.

  Status stored (in the requests):
    status_$ok: the sectors done, or a completion the bits do not fault
    status_$disk_data_check, status_$ecc_error_in_sector_id,
      status_$bad_disk_format, status_$disk_equipment_check,
      status_$disk_seek_error, status_$disk_not_ready,
      status_$disk_driver_logic_error,
      status_$unknown_error_status_from_drive: by the completion code
      and the controller's bits
}

procedure win7_$error_que(in vol: disk_$volume_t; is_timeout: integer;
                          out result: boolean);
  options(val_param);
var
  cb: win7_$ctlr_ptr_t;
  drive: win7_$drive_ptr_t;
  p: win7_$iopb_ptr_t;
  found: boolean;
  r: disk_$io_req_ptr_t;
  err: status_$t;
  n: integer;
  k: integer;
  nxt: win7_$iopb_ptr_t;
  token: pinteger;
  local: win7_$iopb_ptr_t;
begin
  cb := win7_ctlrs[vol.dev_info^.controller];
  drive := addr(cb^.drives[vol.dev_unit]);
  ml_$lock(cb^.lock);
  if is_timeout = 1 then
    crash_system(status_$disk_controller_timeout);
  p := cb^.done;
  found := false;
  if p <> nil then
    repeat
      if (p^.info^.unit = vol.dev_unit) and
         (p^.info^.owner = proc1_$current) then begin
        found := true;
        r := p^.info^.req;

        { the status, from the completion code and the bits }
        case p^.info^.status of
          win7_failed_2: begin
            if (p^.stat & 16#01) <> 0 then begin
              if (p^.error & 16#40) <> 0 then begin
                err.all := status_$disk_data_check;
                drive^.stats.data_checks := drive^.stats.data_checks + 1;
              end
              else if (p^.error & 16#10) <> 0 then begin
                if p^.op = win7_op_format_track then
                  err.all := status_$ok
                else begin
                  err.all := status_$ecc_error_in_sector_id;
                  drive^.stats.data_checks := drive^.stats.data_checks + 1;
                end;
              end
              else if ((p^.error & 16#01) <> 0) or
                      ((p^.error & 16#80) <> 0) then begin
                err.all := status_$bad_disk_format;
                drive^.stats.equip_checks := drive^.stats.equip_checks + 1;
              end
              else if (p^.error & 16#04) <> 0 then begin
                if (p^.stat & 16#20) <> 0 then begin
                  err.all := status_$disk_equipment_check;
                  drive^.stats.equip_checks :=
                    drive^.stats.equip_checks + 1;
                end
                else if (p^.stat & 16#10) = 0 then begin
                  err.all := status_$disk_seek_error;
                  drive^.stats.seek_errors := drive^.stats.seek_errors + 1;
                end
                else if (p^.stat & 16#80) <> 0 then begin
                  err.all := status_$disk_not_ready;
                  drive^.stats.not_ready := drive^.stats.not_ready + 1;
                end
                else begin
                  err.all := status_$disk_driver_logic_error;
                  drive^.stats.data_checks := drive^.stats.data_checks + 1;
                end;
              end
              else if (p^.error & 16#08) <> 0 then
                err.all := status_$ok
              else
                err.all := status_$unknown_error_status_from_drive;
            end
            else if (p^.stat & 16#04) <> 0 then begin
              err.all := status_$ok;
              drive^.stats.data_checks := drive^.stats.data_checks + 1;
            end
            else if (p^.stat & 16#80) <> 0 then begin
              err.all := status_$disk_not_ready;
              drive^.stats.not_ready := drive^.stats.not_ready + 1;
            end
            else
              err.all := status_$unknown_error_status_from_drive;
          end;
          win7_failed_3: begin
            err.all := status_$ok;
            drive^.stats.data_checks := drive^.stats.data_checks + 1;
          end;
          win7_failed_17, win7_failed_18, win7_failed_16: begin
            err.all := status_$disk_driver_logic_error;
            drive^.stats.data_checks := drive^.stats.data_checks + 1;
          end;
        end;

        { the requests: the sectors done, then the rest }
        if (p^.op = win7_op_read) or (p^.op = win7_op_write) then begin
          for k := 1 to p^.done do begin
            r^.status.all := status_$ok;
            r := r^.next;
          end;
          n := p^.done + 1;
          for k := n to p^.info^.count do begin
            r^.status := err;
            r := r^.next;
            if p^.op = win7_op_read then
              drive^.stats.reads := drive^.stats.reads - 1;
            if p^.op = win7_op_write then
              drive^.stats.writes := drive^.stats.writes - 1;
          end;
        end
        else
          r^.status := err;

        { the block, back to the free list }
        nxt := p^.info^.next;
        token := ml_$spin_lock(cb^.spin);
        if p^.info^.prev = nil then
          win7_$move_iopb(cb^.done, cb^.free)
        else begin
          local := p;
          win7_$move_iopb(local, cb^.free);
        end;
        ml_$spin_unlock(cb^.spin, token);
        p := nxt;
      end
      else
        p := p^.info^.next;
    until p = nil;
  if found then
    ec_$advance_without_dispatch(disk_bptbl[proc1_$current].io_ec);
  ml_$unlock(cb^.lock);
end;
