{ EC2_$GET_VAL - the value of an eventcount named by an EC2 number.

  Image addresses:
    sau2  0x00E42BE0  EC2_$GET_VAL

  - 1 up to the highest registered number names a registered level-1
    eventcount (slot 1 the always-ready cell, whose value is the highest
    number itself), 16#101..16#120 one of the PBU pool's.  A failure's
    value is 16#7FFFFFFF.

  Status stored:
    status_$ok: the value was returned
    ec2_$ec1_not_allocated: a PBU number not handed out
    ec2_$bad_eventcount: any other number
}

function ec2_$get_val(in ec: ec2_$ptr_t; out status: status_$t): integer32;
var
  index: linteger;
begin
  status.all := status_$ok;
  index := linteger(ec);

  if (index <> 0) and then (index <= ec2_$max_registered) then
    ec2_$get_val := ec2_$registered_ec1s[index]^.value
  else if (index >= pbu_ec_index_min) and then
          (index <= pbu_ec_index_max) then begin
    if (index - pbu_ec_index_min) in ec2_$pbu_allocated then
      ec2_$get_val := ec2_$pbu_ecs[index - pbu_ec_index_min].ec.value
    else begin
      status.all := ec2_$ec1_not_allocated;
      ec2_$get_val := 16#7FFFFFFF;
    end;
  end
  else begin
    status.all := ec2_$bad_eventcount;
    ec2_$get_val := 16#7FFFFFFF;
  end;
end;
