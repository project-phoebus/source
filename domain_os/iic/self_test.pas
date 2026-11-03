{ IIC_$SELF_TEST - run a line's self test.

  Image addresses:
    sau2  0x00E70A8C  IIC_$SELF_TEST
    sau3  0x00E72090  IIC_$SELF_TEST

  - Without the driver a stub: the controller is not in the system; the
    line and the answer are never touched.
  - With it, the controller runs its self test under the line's send
    lock and the 14 results (0, 1 or 2) are copied out; the receive
    setup is then given again.

  Status stored:
    status_$iic_device_not_in_system: without the driver
    status_$iic_device_not_acquired: the line is free
    iic_command's status: the test, or the receive setup after it
}

procedure iic_$self_test(in line: pinteger; out results: iic_$self_test_t;
                         out status: status_$t);
%if iic_driver %then
var
  st: status_$t;
  i: integer;
%endif
begin
%if iic_driver %then
  with iic_lines[line] do begin
    case state of
      iic_line_free: begin
        status.all := status_$iic_device_not_acquired;
        return;
      end;
      iic_line_up, iic_line_remote_down: begin
        status.all := status_$ok;
      end;
    end;
    ml_$exclusion_start(send_lock);
    iic_command(line, iic_cmd_self_test, st);
    if st.all <> status_$ok then begin
      status := st;
      return;
    end;
    for i := 0 to 13 do
      case iic_$control_page[0][line].cb.self_test[i] of
        0: begin
          results[i] := 0;
        end;
        1: begin
          results[i] := 1;
        end;
        2: begin
          results[i] := 2;
        end;
      end;
    iic_command(line, iic_cmd_receive, st);
    ml_$exclusion_stop(send_lock);
    status := st;
  end;
%else
  status.all := status_$iic_device_not_in_system;
%endif
end;
