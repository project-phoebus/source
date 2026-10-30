{ PBU_$ADVANCE_EC_INT - advance a PBU eventcount at interrupt level.

  Image addresses:
    sau2  0x00E88400  PBU_$ADVANCE_EC_INT

  - Eventcount numbers 16#101..16#120 are the pool's; the record's owner
    must be owner_id.  No dispatch.

  Status stored:
    status_$ok: the eventcount was advanced
    ec2_$bad_eventcount: ec_index is not the pool's, or not owner_id's
}

procedure pbu_$advance_ec_int(in owner_id: integer; in ec_index: linteger;
                              out status: status_$t);
var
  index: linteger;
  slot: integer;
  entry: pbu_$ec_entry_ptr_t;
begin
  status.all := ec2_$bad_eventcount;
  index := ec_index;
  if index < pbu_ec_index_min then
    return;
  if index > pbu_ec_index_max then
    return;

  slot := index - pbu_ec_index_min;
  entry := addr(ec2_$pbu_ecs[slot]);
  if entry^.owner_id <> owner_id then
    return;

  status.all := status_$ok;
  ec_$advance_without_dispatch(entry^.ec);
end;
