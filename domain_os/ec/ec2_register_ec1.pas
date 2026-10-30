{ EC2_$REGISTER_EC1 - give a level-1 eventcount an EC2 number.

  Image addresses:
    sau2  0x00E4293C  EC2_$REGISTER_EC1

  - Under the EC2 lock; an eventcount registered already keeps its
    number, else the next is taken.  The result is the number, as an EC2
    handle; nil when 256 are in use.
  - The search bound is the low word of the highest registered number
    (+0xE9A, inside the longword at +0xE98).

  Status stored:
    status_$ok: the eventcount has a number
    ec2_$no_wait_entries: 256 are in use ("internal table exhausted")
}

function ec2_$register_ec1(ec1: ec_$eventcount_ptr_t;
                           out status: status_$t): ec2_$ptr_t;
  options(val_param);
label
  10;
var
  local_status: status_$t;
  index: integer32;
  i: integer;
begin
  local_status.all := status_$ok;
  ml_$lock(ml_$ec2_lock);

  { an eventcount registered already }
  for i := 1 to ec2_$max_registered do
    if ec2_$registered_ec1s[i] = ec1 then begin
      index := i;
      ec2_$register_ec1 := ec2_$ptr_t(index);
      goto 10;
    end;

  { a new number }
  if ec2_$max_registered >= 256 then begin
    local_status.all := ec2_$no_wait_entries;
    ec2_$register_ec1 := nil;
  end
  else begin
    ec2_$max_registered := ec2_$max_registered + 1;
    ec2_$registered_ec1s[ec2_$max_registered] := ec1;
    index := ec2_$max_registered;
    ec2_$register_ec1 := ec2_$ptr_t(index);
  end;

10:
  ml_$unlock(ml_$ec2_lock);
  status := local_status;
end;
