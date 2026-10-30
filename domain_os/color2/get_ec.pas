{ COLOR2_$GET_EC - the EC2 handle of the graphics board's color
  interrupt eventcount.

  Image addresses:
    sau5  0x00E73534  COLOR2_$GET_EC

  Status stored:
    ec2_$register_ec1's status: the handle was returned, or not
}

procedure color2_$get_ec(out ec: ec2_$ptr_t; out status: status_$t);
begin
  ec := ec2_$register_ec1(addr(color2_$int_ec), status);
end;
