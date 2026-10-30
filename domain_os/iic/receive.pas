{ IIC_$RECEIVE - receive from the internet interface controller.

  Image addresses:
    sau2  0x00E70ABA  IIC_$RECEIVE

  - A stub: the controller is not in the system.  The two count words
    (the fifth argument's, then the third's) are cleared; the others are
    never read.

  Status stored:
    status_$iic_device_not_in_system: always
}

procedure iic_$receive(in arg1: integer32; in arg2: integer32;
                       out count_ret3: pinteger; in arg4: integer32;
                       out count_ret5: pinteger; out status: status_$t);
begin
  status.all := status_$iic_device_not_in_system;
  count_ret5 := 0;
  count_ret3 := 0;
end;
