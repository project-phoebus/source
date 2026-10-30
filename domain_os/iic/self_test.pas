{ IIC_$SELF_TEST - run the internet interface controller's self test.

  Image addresses:
    sau2  0x00E70A8C  IIC_$SELF_TEST

  - A stub: the controller is not in the system.  The two other
    arguments are never read.

  Status stored:
    status_$iic_device_not_in_system: always
}

procedure iic_$self_test(in arg1: integer32; in arg2: integer32;
                         out status: status_$t);
begin
  status.all := status_$iic_device_not_in_system;
end;
