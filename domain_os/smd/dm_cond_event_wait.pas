{ SMD_$DM_COND_EVENT_WAIT - the display manager's conditional event wait.

  Image addresses:
    sau2  0x00E6EFF0  SMD_$DM_COND_EVENT_WAIT
    sau5  0x00E713A0  SMD_$DM_COND_EVENT_WAIT
    sau9  0x3C4757F0  SMD_$DM_COND_EVENT_WAIT

  - Never waits: the first event found is returned.  In order: a borrow
    or return request on a unit the process owns, the keyswitch turned
    off (once per off period), a DM request from the ring.
  - Then the process's own unit's finished scroll or BLT, else no event.
  - With `display_devices' (base/config.ins.pas) the units are the
    devices' (as many as were added), and there is no scroll or BLT
    event: after the ring, no event.
  - event_type's codes are the ordinals of Apollo's smd_$event_t
    (smdu.ins.pas), which cannot be in scope: its smd_$signal is this
    module's SMD_$SIGNAL.

  Status stored:
    status_$ok: an event or no event was returned
    smd_$illegal_caller: nothing else was found and the process has no
      display unit (not with `display_devices')
}

{ TODO(pascal) SMD_$DM_COND_EVENT_WAIT's frame: 8 of its 0x24 bytes not accounted

  The image's frame is 36 bytes, and the code addresses no frame slot at
  all: every local is in a register.  dpc's layout of the seven locals
  and the `with' slots is 28 bytes.  Which declarations or temporaries
  (the two `for' loops' bounds, a `with' over the request entry or the
  second unit element) take the other 8 is not known. }

procedure smd_$dm_cond_event_wait(out event_type: integer;
                                  out data: univ smd_event_dbuf_t;
                                  out data_size: pinteger;
                                  out status: status_$t);
var
  asid: proc1_$asid_t;
  u: integer;
  disp: smd_display_hw_ptr_t;
  hw_flags: smd_hw_event_set_t;
  power_off: boolean;
  i: pinteger;
  unit_num: pinteger;
begin
  status.all := status_$ok;
  asid := proc1_$as_id;

  { a borrow or return request pending on a unit the process owns }
%if display_devices %then
  for u := 1 to smd_$wired_data.unit_count do
%else
  for u := 1 to smd_unit_count do
%endif
    with smd_$wired_data.unit[u] do begin
      disp := hw;
      if (disp^.field_4c <> []) and then (asid = owner_asid) then begin
        hw_flags := disp^.field_4c;
        if 14 in hw_flags then begin
          event_type := smd_$return_req;
          disp^.field_4c := disp^.field_4c - [14];
        end
        else if 15 in hw_flags then begin
          event_type := smd_$borrow_req;
          disp^.field_4c := disp^.field_4c - [15];
        end;
        data[1] := u;
        return;
      end;
    end;

  { the keyswitch, reported once }
  power_off := mmu_$power_off;
  if power_off and then not power_off_reported then begin
    event_type := smd_$keyswitch_off;
    power_off_reported := power_off;
    return;
  end;
  power_off_reported := power_off;

  { a DM request from the ring }
  if smd_request_queue.head <> smd_request_queue.tail then begin
    event_type := smd_$signal_event;
    ml_$lock(ml_$smd_request_lock);
    if smd_request_queue.head <> smd_request_queue.tail then begin
      with smd_request_queue.entries[smd_request_queue.tail] do begin
        data[1] := request_type;
        data_size := param_count;
        for i := 1 to data_size do
          data[i + 1] := params[i];
      end;
      { the read index, 40 wraps to 1 }
      if smd_request_queue.tail >= 40 then
        smd_request_queue.tail := 1
      else
        smd_request_queue.tail := smd_request_queue.tail + 1;
      ml_$unlock(ml_$smd_request_lock);
      ec_$advance(smd_$wired_data.ec_1);
      return;
    end;
    ml_$unlock(ml_$smd_request_lock);
  end;

%if display_devices %then
  event_type := smd_$no_event;
%else
  { the process's own unit: a finished scroll or BLT }
  unit_num := asid_to_unit[asid];
  if unit_num = 0 then
    status.all := smd_$illegal_caller
  else
    with smd_$wired_data.unit[unit_num], hw^ do
      if (asid = field_08) and then (field_1c + 1 <= op_ec.value) then
        begin
        event_type := smd_$scroll_blt_complete;
        field_1c := op_ec.value;
        field_08 := 0;
      end
      else
        event_type := smd_$no_event;
%endif
end;
