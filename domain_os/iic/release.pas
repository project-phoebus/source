{ IIC_$RELEASE - release a line of the internet interface controller.

  Image addresses:
    sau2  0x00E70A68  IIC_$RELEASE
    sau3  0x00E71AE6  IIC_$RELEASE

  - Without the driver a stub: the controller is not in the system, and
    the line is never read.

  Status stored:
    status_$iic_device_not_in_system: without the driver
    IIC_$$RELEASE's status
}

procedure iic_$release(in line: pinteger; out status: status_$t);
begin
%if iic_driver %then
  iic_$$release(line, status);
%else
  status.all := status_$iic_device_not_in_system;
%endif
end;
