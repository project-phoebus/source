{ IIC_$ACQUIRE - acquire the internet interface controller.

  Image addresses:
    sau2  0x00E70A56  IIC_$ACQUIRE

  - A stub: the controller is not in the system.  The first argument is
    never read.

  Status stored:
    status_$iic_device_not_in_system: always
}

procedure iic_$acquire(in arg1: integer32; out status: status_$t);
begin
  status.all := status_$iic_device_not_in_system;
end;
