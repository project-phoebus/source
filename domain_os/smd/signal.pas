{ SMD_$SIGNAL - queue a request for the display manager.

  Image addresses:
    sau2  0x00E6F1DA  SMD_$SIGNAL
    sau5  0x00E71590  SMD_$SIGNAL
    sau9  0x3C47599A  SMD_$SIGNAL

  - The ring's room is tested under the SMD request lock; a full ring is
    waited out (on ec_1) with the lock released.
  - The entry gets the calling process's number, the count and the
    words; ec_2, the display manager's wake-up, is advanced.

  Status stored:
    status_$ok: the request was queued
    smd_$illegal_unit: the unit is not valid
    smd_$invalid_buffer_size: count is not 1..16
}

{ TODO(pascal) SMD_$SIGNAL's frame: 12 of its 0x18 bytes not accounted

  The image's frame has 24 bytes and addresses no frame slot: ec_value,
  the copy's count and the loop invariants are held in registers.  dpc's
  layout of ec_value, i and the `with' slot (`--dump-locals' on the
  gate's copy) is 12 bytes.  Which declarations or temporaries take the
  other 12 (the `for' bound count + 1, the `repeat' loop's or the
  EC_$WAIT call's) is not known. }

procedure smd_$signal(in unit: integer; in request: univ smd_$request_t;
                      in count: pinteger; out status: status_$t);
var
  ec_value: integer32;
  i: pinteger;
begin
  if not smd_$validate_unit(unit) then begin
    status.all := smd_$illegal_unit;
    return;
  end;
  if (count = 0) or else (count > 16) then begin
    status.all := smd_$invalid_buffer_size;
    return;
  end;

  { wait for room in the ring }
  repeat
    ec_value := smd_$wired_data.ec_1.value;
    ml_$lock(ml_$smd_request_lock);
    if smd_request_queue.head = smd_request_queue.tail then exit;
    if smd_request_queue.head > smd_request_queue.tail then
      if 39 - (smd_request_queue.head - smd_request_queue.tail) > 0 then
        exit;
    if smd_request_queue.tail - smd_request_queue.head - 1 > 0 then
      exit;
    ml_$unlock(ml_$smd_request_lock);
    discard(ec_$wait(addr(smd_$wired_data.ec_1), addr(ec_$nil_ec),
                     addr(ec_$nil_ec), ec_value + 1, 0, 0));
  until false;

  { the entry at the write index }
  with smd_request_queue.entries[smd_request_queue.head] do begin
    request_type := proc1_$current;
    param_count := count;
    for i := 2 to count + 1 do
      params[i - 1] := request[i - 1];
  end;

  { the write index, 40 wraps to 1 }
  if smd_request_queue.head >= 40 then
    smd_request_queue.head := 1
  else
    smd_request_queue.head := smd_request_queue.head + 1;
  ml_$unlock(ml_$smd_request_lock);
  ec_$advance(smd_$wired_data.ec_2);
  status.all := status_$ok;
end;
