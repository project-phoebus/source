{ EC2_$ALLOCATE_EC1 - hand out a PBU eventcount.

  Image addresses:
    sau2  0x00E429DA  EC2_$ALLOCATE_EC1

  - Under the EC2 lock, the first of the PBU pool's 32 records that is
    free, or pending (released while waited on) with its waiter count
    back to zero, is handed out with its eventcount initialized.
  - The result is its number, 16#101 + the record's index; nil when
    none is free.

  Status stored:
    status_$ok: a record was handed out
    ec2_$no_more_ecs: none is free
}

function ec2_$allocate_ec1(out status: status_$t): ec2_$ptr_t;
var
  i: 0..31;
begin
  ml_$lock(ml_$ec2_lock);

  for i := 0 to 31 do
    with ec2_$pbu_ecs[i] do begin
      if (i in ec2_$pbu_pending) and then (reserved1 = 0) then begin
        ec2_$pbu_allocated := ec2_$pbu_allocated + [i];
        ec2_$pbu_pending := ec2_$pbu_pending - [i];
      end
      else if i in ec2_$pbu_allocated then
        next;
      ec2_$pbu_allocated := ec2_$pbu_allocated + [i];
      ec2_$allocate_ec1 := ec2_$ptr_t(linteger(i) + pbu_ec_index_min);
      ec_$init(ec);
      reserved1 := 0;
      ml_$unlock(ml_$ec2_lock);
      status.all := status_$ok;
      return;
    end;

  ec2_$allocate_ec1 := nil;
  ml_$unlock(ml_$ec2_lock);
  status.all := ec2_$no_more_ecs;
end;
