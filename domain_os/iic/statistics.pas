{ IIC_$STATISTICS - return the internet interface controller's
  statistics.

  Image addresses:
    sau2  0x00E70A7A  IIC_$STATISTICS

  - A stub: the controller is not in the system.  The two other
    arguments are never read.

  Status stored:
    status_$iic_device_not_in_system: always
}

procedure iic_$statistics(in arg1: integer32; in arg2: integer32;
                          out status: status_$t);
begin
  status.all := status_$iic_device_not_in_system;
end;
