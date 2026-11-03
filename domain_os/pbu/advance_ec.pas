{ PBU_$ADVANCE_EC - advance a PBU eventcount.

  Image addresses:
    sau3  0x00E589B2  PBU_$ADVANCE_EC
    sau5  0x00E589B2  PBU_$ADVANCE_EC

  - PBU_$ADVANCE_EC_INT's test, under the exclusion lock, with a
    dispatch (EC_$ADVANCE).

  Status stored:
    status_$ok: the eventcount was advanced
    ec2_$bad_eventcount: ec_index is not the pool's, or not the unit's
}

procedure pbu_$advance_ec(in unit: integer; in ec_index: linteger;
                          out status: status_$t);
var
  index: linteger;
  slot: integer;
  entry: pbu_$ec_entry_ptr_t;
begin
  status.all := ec2_$bad_eventcount;
  ml_$exclusion_start(pbu_$exclusion_lock);
  index := ec_index;
  if (index >= pbu_ec_index_min) and then (index <= pbu_ec_index_max) then
  begin
    slot := index - pbu_ec_index_min;
    entry := addr(ec2_$pbu_ecs[slot]);
    if entry^.owner_id = unit then begin
      status.all := status_$ok;
      ec_$advance(entry^.ec);
    end;
  end;
  ml_$exclusion_stop(pbu_$exclusion_lock);
end;
