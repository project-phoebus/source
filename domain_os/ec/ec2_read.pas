{ EC2_$READ - read a level-2 eventcount.

  Image addresses:
    sau2  0x00E42C7C  EC2_$READ

  - An address above 1000 is read directly; a smaller value is an EC2
    number, read by EC2_$GET_VAL (its status ignored).

  Status stored: none.
}

function ec2_$read(in ec: ec2_$eventcount_t): integer32;
var
  status: status_$t;
  ecp: ec2_$ptr_t;
begin
  if linteger(addr(ec)) > 1000 then
    ec2_$read := ec.value
  else begin
    ecp := addr(ec);
    ec2_$read := ec2_$get_val(ecp, status);
  end;
end;
