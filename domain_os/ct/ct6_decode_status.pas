{ ct6_decode_status - the status of the command the second controller
  ended.

  Image addresses:
    sau6  0x7807DC88  ct6_decode_status (module-local)

  - From the failed block's status word (ct6_status) and the drive's
    status word (ct_dstat) CT6_$INT kept: a status word other than 0 or
    one whose low byte is 1 is a controller time-out; otherwise the
    drive's status is decoded through the module's table, as
    ct_decode_status does, after a load command even without a failed
    block.
  - The first end of tape is reported once, then taken as success; each
    takes a block off the chain's count left (ct6_resid).

  Returns:
    0: the command succeeded
    status_$ct_controller_timeout: the block's status word
    the table's status: a drive status the table matches
    status_$ct_unrecognized_drive_status: one it does not

  Status stored: none.
}

function ct6_decode_status: integer32; internal;
label
  1;
var
  i: integer;
  result: integer32;
begin
  if not ct6_loading and then (ct6_status = 0) then begin
    ct6_decode_status := 0;
    return;
  end;
  if ((ct6_status & 16#FF) <> 1) and then (ct6_status <> 0) then begin
    ct6_decode_status := status_$ct_controller_timeout;
    return;
  end;

  result := status_$ct_unrecognized_drive_status;
  if ct_reading then begin
    ct_dstat.bits := ct_dstat.bits - [12];
    if (ct_dstat.all & 16#7F00) = 0 then
      ct_dstat.bits := ct_dstat.bits - [15];
    if ct_dstat.all = 0 then begin
      ct6_decode_status := 0;
      return;
    end;
  end;
  for i := 1 to 18 do
    if (ct_dstat.all & ct_status_map[i].mask) = ct_status_map[i].value
    then begin
      result := ct_status_map[i].status;
      if ct_status_map[i].status = status_$ct_end_of_tape then begin
        ct6_resid := ct6_resid - 1;
        if ct_eot_seen then
          result := 0
        else
          ct_eot_seen := true;
      end;
      goto 1;
    end;
1:
  ct6_decode_status := result;
end;
