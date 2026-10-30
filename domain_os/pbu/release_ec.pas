{ PBU_$RELEASE_EC - release a PBU unit's eventcount.

  Image addresses:
    sau5  0x00E593AC  PBU_$RELEASE_EC

  - Undoes PBU_$ALLOCATE_EC under the exclusion lock: the eventcount's
    record gives up its owner and leaves the unit's list, and the
    eventcount is released (EC2_$RELEASE_EC1).

  Status stored:
    ec2_$release_ec1's status: the eventcount was released, or not
    pbu_$get_ptr's status: the unit is not the caller's
    ec2_$get_ec1_addr's status: ec is not an eventcount
    status_$pbu_invalid_unit_number: the eventcount is not the unit's
}

procedure pbu_$release_ec(in unit: integer; in ec: ec2_$ptr_t;
                          out status: status_$t);
var
  size: integer32;
  entry: pbu_$ec_entry_ptr_t;
  area: pbu_$stack_area_ptr_t;
begin
  area := pbu_$get_ptr(unit, pbu_ptr_stack, size, status);
  if status.all <> status_$ok then
    return;
  ml_$exclusion_start(pbu_$exclusion_lock);
  entry := pbu_$ec_entry_ptr_t(ec2_$get_ec1_addr(ec, status));
  if status.all = status_$ok then begin
    if unit <> entry^.owner_id then
      status.all := status_$pbu_invalid_unit_number
    else begin
      entry^.owner_id := 0;
      if entry^.prev = nil then
        area^.ecs := entry^.next
      else
        entry^.prev^.next := entry^.next;
      if entry^.next <> nil then
        entry^.next^.prev := entry^.prev;
      ec2_$release_ec1(ec, status);
    end;
  end;
  ml_$exclusion_stop(pbu_$exclusion_lock);
end;
