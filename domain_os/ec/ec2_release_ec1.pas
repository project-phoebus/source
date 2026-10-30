{ EC2_$RELEASE_EC1 - give back a PBU eventcount.

  Image addresses:
    sau2  0x00E42B32  EC2_$RELEASE_EC1

  - Under the EC2 lock.  A record nobody waits on is freed at once;
    else its waiters are woken and the record marked pending, for
    EC2_$ALLOCATE_EC1 to reuse once the count is back to zero.

  Status stored:
    status_$ok: the eventcount was given back
    ec2_$bad_eventcount: ec is not a PBU number, 16#101..16#120
    ec2_$ec1_not_allocated: it is not handed out
}

procedure ec2_$release_ec1(in ec: ec2_$ptr_t; out status: status_$t);
var
  local_status: status_$t;
  index: linteger;
  slot: integer;
begin
  ml_$lock(ml_$ec2_lock);
  index := linteger(ec);

  if (index < pbu_ec_index_min) or else (index > pbu_ec_index_max) then
    local_status.all := ec2_$bad_eventcount
  else begin
    slot := index - pbu_ec_index_min;
    if not (slot in ec2_$pbu_allocated) then
      local_status.all := ec2_$ec1_not_allocated
    else
      with ec2_$pbu_ecs[slot] do begin
        local_status.all := status_$ok;
        if reserved1 = 0 then
          ec2_$pbu_allocated := ec2_$pbu_allocated - [slot]
        else begin
          ec_$advance_all(ec);
          ec2_$pbu_pending := ec2_$pbu_pending + [slot];
        end;
      end;
  end;

  ml_$unlock(ml_$ec2_lock);
  status := local_status;
end;
