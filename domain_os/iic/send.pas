{ IIC_$SEND - send through the internet interface controller.

  Image addresses:
    sau2  0x00E70A9E  IIC_$SEND

  - A stub: the controller is not in the system.  The five other
    arguments are never read.

  Status stored:
    status_$iic_device_not_in_system: always
}

procedure iic_$send(in arg1: integer32; in arg2: integer32;
                    in arg3: integer32; in arg4: integer32;
                    in arg5: integer32; out status: status_$t);
begin
  status.all := status_$iic_device_not_in_system;
end;
