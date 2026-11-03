{ IIC_$ACQUIRE - acquire a line of the internet interface controller.

  Image addresses:
    sau2  0x00E70A56  IIC_$ACQUIRE
    sau3  0x00E71A82  IIC_$ACQUIRE

  - Without the driver a stub: the controller is not in the system, and
    the line is never read.
  - With it, the line is acquired for the calling address space.

  Status stored:
    status_$iic_device_not_in_system: without the driver
    iic_do_acquire's status
}

procedure iic_$acquire(in line: pinteger; out status: status_$t);
begin
%if iic_driver %then
  iic_do_acquire(line, proc1_$as_id, status);
%else
  status.all := status_$iic_device_not_in_system;
%endif
end;
