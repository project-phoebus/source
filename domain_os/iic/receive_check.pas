{ IIC_$RECEIVE_CHECK - check the internet interface controller for a
  received message.

  Image addresses:
    sau2  0x00E70ADE  IIC_$RECEIVE_CHECK

  - A stub: the controller is not in the system.  The result is false;
    the first argument is never read.

  Status stored:
    status_$iic_device_not_in_system: always
}

function iic_$receive_check(in arg1: integer32;
                            out status: status_$t): boolean;
begin
  status.all := status_$iic_device_not_in_system;
  iic_$receive_check := false;
end;
