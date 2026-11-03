{ IIC_$RECEIVE_CHECK - whether a message waits on a line of the internet
  interface controller.

  Image addresses:
    sau2  0x00E70ADE  IIC_$RECEIVE_CHECK
    sau3  0x00E71F4E  IIC_$RECEIVE_CHECK

  - Without the driver a stub: the controller is not in the system.  The
    result is false; the line is never read.
  - With it, true while the line's socket has advanced to the value the
    next receive waits for.  On a line that is not up the result is not
    assigned.

  Status stored:
    status_$iic_device_not_in_system: without the driver
    status_$ok: the line is up
    status_$iic_remote_device_not_acquired: the other end is down
    status_$iic_device_not_acquired: the line is free
}

function iic_$receive_check(in line: pinteger;
                            out status: status_$t): boolean;
begin
%if iic_driver %then
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
    ml_$exclusion_start(rcv_lock);
    iic_$receive_check :=
      ec_$read(sock_$socket_ptr[sock]^.ec) >= sock_wait;
    ml_$exclusion_stop(rcv_lock);
  end;
%else
  status.all := status_$iic_device_not_in_system;
  iic_$receive_check := false;
%endif
end;
