{ ct_read_status - read the tape drive's six status bytes and decode them.

  Image addresses:
    sau7  0x3C485638  ct_read_status (module-local)
    sau8  0x03C7A26E  ct_read_status (module-local)

  - Each byte is taken when the adapter shows ready and acknowledged
    with the request, which is dropped once the drive drops ready (up to
    11 waits of ct_status_delay); bytes 0 and 1 are the drive's status
    word, 2 and 3 its count of data errors, 4 and 5 of underruns.
  - The status word is decoded as the other form's drive status: read
    with ct_reading, the bits the drive sets on every read are ignored;
    the first end of tape is reported once, then taken as success.  The
    counts are added to ct_total_2c and ct_total_2e.
  - The result is a status: a failure to read the bytes, else the
    decoded one.

  Status stored: none.
}

function ct_read_status: integer32; internal;
label
  1;
var
  status: status_$t;
  regs: ct_$atbus_regs_ptr_t;
  k: integer;
  timeout: integer32;
  j: integer;
  ready: boolean;
  i: integer;
  result: integer32;
begin
  ct_drive_status.all := 0;
  status.all := status_$ok;
  regs := ct_regs;
  for k := 0 to 5 do begin
    timeout := 16;
    if not ct_wait_ready(timeout, status) then
      exit;
    case k of
      0: ct_drive_status.hi := regs^.data;
      1: ct_drive_status.lo := regs^.data;
      2: ct_errors.hi := regs^.data;
      3: ct_errors.lo := regs^.data;
      4: ct_underruns.hi := regs^.data;
      5: ct_underruns.lo := regs^.data;
    end;
    regs^.ctl := ct_ctl_request;
    j := 0;
    repeat
      time_$wait(time_$relative, ct_status_delay, status);
      if ct_regs^.stat.not_ready then
        ready := false
      else
        ready := true;
      j := j + 1;
    until not ready or (j > 10);
    if not ct_regs^.stat.not_ready then
      exit;
    regs^.ctl := 0;
  end;
  if status.all <> status_$ok then begin
    ct_read_status := status.all;
    return;
  end;

  ct_dstat.all := ct_drive_status.all;
  if ct_reading then begin
    ct_dstat.bits := ct_dstat.bits - [12];
    if (ct_dstat.all & 16#7F00) = 0 then
      ct_dstat.bits := ct_dstat.bits - [15];
    if ct_dstat.all = 0 then begin
      ct_read_status := 0;
      return;
    end;
  end;
  for i := 1 to 18 do
    if (ct_dstat.all & ct_status_map[i].mask) = ct_status_map[i].value
    then begin
      result := ct_status_map[i].status;
      if ct_status_map[i].status = status_$ct_end_of_tape then
        if ct_eot_seen then
          result := 0
        else
          ct_eot_seen := true;
      goto 1;
    end;
  result := status_$ct_unrecognized_drive_status;
1:
  ct_total_2c := ct_total_2c + ct_errors.all;
  ct_total_2e := ct_total_2e + ct_underruns.all;
  ct_read_status := result;
end;
