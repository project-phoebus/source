{ PBU_$WAIT - wait for a PBU unit's interrupt.

  Image addresses:
    sau3  0x00E89EE8  PBU_$WAIT
    sau5  0x00E922B2  PBU_$WAIT
    sau8  0x03CA5B64  PBU_$WAIT

  - With a timeout of 0, the result is at once 0 when the unit's
    interrupt is pending, 1 when not.
  - Otherwise, unless it is pending (0), EC_$WAIT's result: the unit's
    eventcount, (timeout + 125) div 250 ticks (at least one) of
    TIME_$CLOCKH, and with allow_quit a quit (2, noted as seen).
  - The pending flag is cleared in every case.

  Status stored:
    pbu_map_check_unit's status: the unit is set up, or not
}

function pbu_$wait(in unit: integer; in timeout: integer32;
                   in allow_quit: boolean; out status: status_$t): integer;
var
  dcte: pbu_$dcte_ptr_t;
  asid: integer;
  t: integer32;
  ticks: integer32;
  ec_value: integer32;
  quit_ec: ec_$eventcount_ptr_t;
  quit_value: integer32;
  answer: integer;
begin
  dcte := pbu_map_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  asid := proc1_$as_id;
  t := timeout;
  if t = 0 then begin
    if dcte^.flags.int_pending then
      answer := pbu_$wait_interrupt
    else
      answer := pbu_$wait_timed_out;
  end
  else begin
    ec_value := dcte^.ec.value + 1;
    ticks := (t + 125) div 250;
    if ticks = 0 then
      ticks := 1;
    answer := pbu_$wait_interrupt;
    if not dcte^.flags.int_pending then begin
      if allow_quit then begin
        quit_ec := addr(fim_$quit_ec[asid]);
        quit_value := fim_$quit_value[asid] + 1;
      end
      else begin
        quit_ec := nil;
        quit_value := 0;
      end;
      answer := ec_$wait(addr(dcte^.ec), addr(time_$clockh_ec), quit_ec,
                         ec_value, time_$clockh + ticks, quit_value);
      if answer = pbu_$wait_quit then
        fim_$quit_value[asid] := fim_$quit_ec[asid].value;
    end;
  end;
  dcte^.flags.int_pending := false;
  pbu_$wait := answer;
end;
