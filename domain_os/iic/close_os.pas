{ IIC_$CLOSE_OS - close a channel MAC_OS opened (the driver's close_os).

  Image addresses:
    sau3  0x00E85E58  IIC_$CLOSE_OS

  - Under the line's send lock: the channel is closed and its ranges
    taken out of the table (each replaced by the last).

  Status stored:
    status_$ok: the channel was closed
    status_$iic_remote_device_not_acquired: the other end is down
    status_$iic_device_not_acquired: the line is free
    status_$iic_operation_aborted: no such open channel
}

[section(iic_aqwrd_proc, iic_aqwrd_data)]
procedure iic_$close_os(line: integer; var callback_data: pinteger;
                        out status: status_$t);
  options(val_param);
var
  i: pinteger;
begin
  with iic_lines[line] do begin
    case state of
      iic_line_remote_down: begin
        status.all := status_$iic_remote_device_not_acquired;
        return;
      end;
      iic_line_free: begin
        status.all := status_$iic_device_not_acquired;
        return;
      end;
      iic_line_up: begin
        status.all := status_$ok;
      end;
    end;
    ml_$exclusion_start(send_lock);
    if (callback_data = 0) or else (callback_data > 4) or else
       not slots[callback_data].open then begin
      ml_$exclusion_stop(send_lock);
      status.all := status_$iic_operation_aborted;
      return;
    end;
    slots[callback_data].open := false;
    i := 1;
    while i <= type_count do
      if types[i].entry.slot = callback_data then begin
        types[i].entry := types[type_count].entry;
        type_count := type_count - 1;
      end
      else
        i := i + 1;
    ml_$exclusion_stop(send_lock);
    status.all := status_$ok;
  end;
end;
