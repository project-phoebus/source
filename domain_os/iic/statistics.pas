{ IIC_$STATISTICS - return a line's counters.

  Image addresses:
    sau2  0x00E70A7A  IIC_$STATISTICS
    sau3  0x00E71FE2  IIC_$STATISTICS

  - Without the driver a stub: the controller is not in the system; the
    line and the record are never touched.
  - With it, a line that is not free returns its counters (a line that
    is free leaves the record alone).

  Status stored:
    status_$iic_device_not_in_system: without the driver
    status_$ok: the counters were returned
    status_$iic_device_not_acquired: the line is free
}

procedure iic_$statistics(in line: pinteger; out stats: univ iic_$stats_t;
                          out status: status_$t);
begin
%if iic_driver %then
  with iic_lines[line] do begin
    case state of
      iic_line_free: begin
        status.all := status_$iic_device_not_acquired;
        return;
      end;
      iic_line_remote_down, iic_line_up: begin
        status.all := status_$ok;
      end;
    end;
    stats.counts := counts;
    stats.errors := errors;
  end;
%else
  status.all := status_$iic_device_not_in_system;
%endif
end;
