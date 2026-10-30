{ EC2_$GET_EC1_ADDR - the address of the level-1 eventcount behind an EC2
  number.

  Image addresses:
    sau2  0x00E42A8A  EC2_$GET_EC1_ADDR

  - Under the EC2 lock.  A registered number above 1 gives its level-1
    eventcount, a PBU number handed out its pool record's; else the
    result is 0.

  Status stored:
    status_$ok: the address was returned
    ec2_$bad_eventcount: the number is neither
    ec2_$ec1_not_allocated: a PBU number not handed out
}

function ec2_$get_ec1_addr(in ec: ec2_$ptr_t; out status: status_$t):
  integer32; options(a0_return);
var
  local_status: status_$t;
  index: linteger;
  slot: integer;
begin
  ml_$lock(ml_$ec2_lock);
  ec2_$get_ec1_addr := 0;
  index := linteger(ec);

  if (index > 1) and then (index <= ec2_$max_registered) then begin
    ec2_$get_ec1_addr := integer32(ec2_$registered_ec1s[index]);
    local_status.all := status_$ok;
  end
  else if (index < pbu_ec_index_min) or else
          (index > pbu_ec_index_max) then
    local_status.all := ec2_$bad_eventcount
  else begin
    slot := index - pbu_ec_index_min;
    if not (slot in ec2_$pbu_allocated) then
      local_status.all := ec2_$ec1_not_allocated
    else begin
      ec2_$get_ec1_addr := integer32(addr(ec2_$pbu_ecs[slot].ec));
      local_status.all := status_$ok;
    end;
  end;

  ml_$unlock(ml_$ec2_lock);
  status := local_status;
end;
