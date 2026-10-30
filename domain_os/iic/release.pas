{ IIC_$RELEASE - release the internet interface controller.

  Image addresses:
    sau2  0x00E70A68  IIC_$RELEASE

  - A stub: the controller is not in the system.  The first argument is
    never read.

  Status stored:
    status_$iic_device_not_in_system: always
}

procedure iic_$release(in arg1: integer32; out status: status_$t);
begin
  status.all := status_$iic_device_not_in_system;
end;
