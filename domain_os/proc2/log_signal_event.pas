{ proc2_$log_signal_event - audit a signal sent to a process or a process
  group.

  Image addresses:
    sau2  0x00E3E748  proc2_$log_signal_event (module-local)

  - With auditing on, a record (the event's UID, the signal, its
    parameter, the target's address space and UNIX id) is logged with
    the sender's status.

  Status stored: none.
}

procedure proc2_$log_signal_event(event_type: integer; target_idx: integer;
                                  signal: integer; param: status_$t;
                                  success: status_$t); internal;
var
  event: proc2_signal_audit_event_t;
  flags: pinteger;
begin
  if not audit_$enabled then
    return;
  event.event_uid.high := 16#4165836C;
  event.event_uid.low :=
    lshft(event_type & 16#FF, 24) + 16#FDED;
  event.signal := signal;
  event.param := param;
  if event_type = proc2_signal_event_pgroup then begin
    event.upid := proc2_$pgroup_table[target_idx].upgid;

    event.asid := 0;
  end
  else begin
    event.asid := proc2_$info_table[target_idx].asid;

    event.upid := proc2_$info_table[target_idx].upid;

  end;
  if success.all = 0 then
    flags := 0
  else
    flags := 1;
  audit_$log_event(event.event_uid, flags, success, event.param, 10);

end;
