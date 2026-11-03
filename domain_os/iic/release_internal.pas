{ IIC_$$RELEASE - stop a line and set it free (the driver record's
  stop).

  Image addresses:
    sau3  0x00E71AF8  IIC_$$RELEASE

  - The guardian is asked to stop the line under the line's send lock;
    the line is free afterwards, whatever the answer.

  Status stored:
    the guardian's status: the line was stopped, or not
    status_$iic_device_not_acquired: the line is free
}

procedure iic_$$release(in line: pinteger; out status: status_$t);
var
  st: status_$t;
begin
  with iic_lines[line] do
  case state of
    iic_line_free: begin
      st.all := status_$iic_device_not_acquired;
    end;
    iic_line_up, iic_line_remote_down: begin
      ml_$exclusion_start(send_lock);
      call_guardian(line, stop_ec, st);
      ml_$exclusion_stop(send_lock);
      state := iic_line_free;
    end;
  end;
  status := st;
end;
