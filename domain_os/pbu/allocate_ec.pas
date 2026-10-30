{ PBU_$ALLOCATE_EC - allocate an eventcount for a PBU unit.

  Image addresses:
    sau5  0x00E58A2E  PBU_$ALLOCATE_EC

  - Under the exclusion lock a level-1 eventcount (EC2_$ALLOCATE_EC1),
    whose record goes at the head of the unit's stack area's list with
    the unit as its owner.  The result is its EC2 handle, unset when
    PBU_$GET_PTR fails.

  Status stored:
    ec2_$allocate_ec1's status: the eventcount was allocated, or not
    pbu_$get_ptr's status: the unit is not the caller's
}

function pbu_$allocate_ec(in unit: integer; out status: status_$t):
  ec2_$ptr_t;
var
  area: pbu_$stack_area_ptr_t;
  size: integer32;
  ec: ec2_$ptr_t;
  entry: pbu_$ec_entry_ptr_t;
  get_status: status_$t;
begin
  area := pbu_$get_ptr(unit, pbu_ptr_stack, size, status);
  if status.all <> status_$ok then
    return;
  ml_$exclusion_start(pbu_$exclusion_lock);
  ec := ec2_$allocate_ec1(status);
  if status.all = status_$ok then begin
    entry := pbu_$ec_entry_ptr_t(ec2_$get_ec1_addr(ec, get_status));
    entry^.prev := nil;
    entry^.next := area^.ecs;
    if entry^.next <> nil then
      entry^.next^.prev := entry;
    area^.ecs := entry;
    entry^.owner_id := unit;
  end;
  ml_$exclusion_stop(pbu_$exclusion_lock);
  pbu_$allocate_ec := ec;
end;
