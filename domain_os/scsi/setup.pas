%if scsi_mailbox_ctlr %then
{ SCSI_$SETUP - acquire a device.

  Image addresses:
    sau7  0x3C4B8F34  SCSI_$SETUP

  - With the mailbox host adapter: under scsi_$exclusion_lock, a device
    already set up for the bus and target refuses (but one of
    scsi_any_owner's); otherwise a free record is set up for the current
    process, its eventcounts initialized and its last status cleared, and
    the first device wires the module's code and data.
  - The handle's low word is the record's number; its high word is not
    set.  The acquisition is audited.

  Status stored:
    status_$ok: the device was set up
    status_$scsi_bad_parameter: the bus or the target out of range
    status_$scsi_device_in_use: the target is the adapter's, or another
      process holds the device
    status_$scsi_bus_not_present: no bus, or not bus 0
    status_$scsi_device_already_acquired: the current process holds it
    status_$scsi_all_devices_in_use: no record is free
}

procedure scsi_$setup(in bus: integer; in target: integer;
                      out handle: scsi_$handle_t; out status: status_$t);
label
  9;
type
  event_t = record
    bus: integer;
    target: integer;
  end;
var
  b: integer;
  tg: integer;
  st: status_$t;
  i: integer;
  slot: integer;
  t: scsi_tinfo_ptr_t;
  cb: scsi_mb_cb_ptr_t;
  h: scsi_$handle_t;
  audit_flags: pinteger;
  event: event_t;
begin
  b := bus;
  tg := target;
  status.all := status_$ok;
  if not scsi_$present then
    status.all := status_$scsi_bus_not_present
  else if (pinteger(b) > scsi_max_bus) or (pinteger(tg) > scsi_host_id) then
    status.all := status_$scsi_bad_parameter
  else if tg = scsi_host_id then
    status.all := status_$scsi_device_in_use
  else if b <> 0 then
    status.all := status_$scsi_bus_not_present
  else begin
    st := status;
    ml_$exclusion_start(scsi_$exclusion_lock);
    for i := 0 to scsi_max_dev do
      with scsi_$tinfo_list[i] do
        if (scsi_tf_in_use in flags) and (bus = b) and (target = tg) then
        begin
          if owner <> scsi_any_owner then
            if owner = proc1_$current then
              st.all := status_$scsi_device_already_acquired
            else
              st.all := status_$scsi_device_in_use;
          exit;
        end;
    if st.all <> status_$ok then
      goto 9;

    { a free record }
    t := nil;
    for i := 0 to scsi_max_dev do begin
      slot := i;
      if not (scsi_tf_in_use in scsi_$tinfo_list[slot].flags) then begin
        t := addr(scsi_$tinfo_list[slot]);
        exit;
      end;
    end;
    if t = nil then begin
      st.all := status_$scsi_all_devices_in_use;
      goto 9;
    end;
    cb := addr(scsi_$cb[b]);
    t^.flags := t^.flags + [scsi_tf_in_use];
    t^.next_id := 0;
    t^.flags := t^.flags - [scsi_tf_sys];
    ec_$init(t^.done_ec);
    ec_$init(t^.reset_ec);
    t^.wait_id := 0;
    t^.last_id := 0;
    t^.scsi_status := scsi_$st_other;
    t^.status.all := status_$ok;
    t^.done_count := 0;
    t^.dev := slot;
    t^.bus := b;
    t^.target := tg;
    t^.lun := 0;
    t^.flags := t^.flags * [0..6, scsi_tf_sys, scsi_tf_in_use];
    t^.owner := proc1_$current;
    t^.asid := proc1_$as_id;
    t^.iova := 0;
    t^.iova_end := 0;
    cb^.open_count := cb^.open_count + 1;
    scsi_open_count := scsi_open_count + 1;
    if scsi_open_count = 1 then
      scsi_wire_driver;
    h.dev := slot;
9:
    ml_$exclusion_stop(scsi_$exclusion_lock);
    if st.all = status_$ok then
      handle := h;
    status := st;
  end;

  if audit_$enabled then begin
    if status.all = status_$ok then
      audit_flags := 0
    else
      audit_flags := 1;
    event.bus := bus;
    event.target := target;
    audit_$log_event(audit_$scsi_acquire_eu, audit_flags, status, event, 4);
  end;
end;
%else
{ SCSI_$SETUP - acquire a device.

  Image addresses:
    sau9  0x3C4A6646  SCSI_$SETUP

  - The target becomes the current process's, its lists and eventcount
    cleared, its generation the clock's low word (the handle's first
    word); the driver's own pages are wired with the first device.
  - Audited (AUDIT_$SCSI_ACQUIRE_EU, the bus and target) when auditing
    is on, whatever the outcome.

  Status stored:
    status_$ok: the device was set up
    status_$scsi_bus_not_present: no bus, or a bus other than 0
    status_$scsi_bad_parameter: a bus above 3 or a target above 7
    status_$scsi_device_in_use: the controller's id, or a device already
      set up
}

procedure scsi_$setup(in bus: integer; in target: integer;
                      out handle: scsi_$handle_t; out status: status_$t);
var
  b: integer;
  t: integer;
  st: status_$t;
  tgt: scsi_target_ptr_t;
  cb: scsi_cb_ptr_t;
  h: scsi_$handle_t;
  flags: pinteger;
  data: record
    bus: integer;                         { 0x00 }
    target: integer;                      { 0x02 }
  end;
begin
  b := bus;
  t := target;
  status.all := status_$ok;
  if not scsi_$present then
    status.all := status_$scsi_bus_not_present
  else if (pinteger(b) > scsi_max_bus) or else (pinteger(t) > scsi_host_id) then
    status.all := status_$scsi_bad_parameter
  else if t = scsi_host_id then
    status.all := status_$scsi_device_in_use
  else if b <> 0 then
    status.all := status_$scsi_bus_not_present
  else begin
    st := status;
    ml_$exclusion_start(scsi_$exclusion_lock);
    tgt := addr(scsi_$cb[b].target[t]);
    if tgt^.allocated = true then
      st.all := status_$scsi_device_in_use
    else begin
      cb := addr(scsi_$cb[b]);
      tgt^.allocated := true;
      tgt^.next_id := 0;
      tgt^.sys_device := false;
      ec_$init(tgt^.ec);
      tgt^.active := false;
      tgt^.pend_head := nil;
      tgt^.pend_tail := nil;
      tgt^.done_head := nil;
      tgt^.done_tail := nil;
      tgt^.owner := proc1_$current;
      tgt^.owner_asid := proc1_$as_id;
      cb^.open_count := cb^.open_count + 1;
      scsi_open_count := scsi_open_count + 1;
      if scsi_open_count = 1 then
        scsi_wire_driver;
      h.all := 0;
      h.gen := time_$clockh;
      tgt^.gen := h.gen;
      h.bus := b;
      h.target := t;
    end;
    ml_$exclusion_stop(scsi_$exclusion_lock);
    if st.all = status_$ok then
      handle := h;
    status := st;
  end;

  if audit_$enabled then begin
    if status.all = status_$ok then
      flags := 0
    else
      flags := 1;
    data.bus := bus;
    data.target := t;
    audit_$log_event(audit_$scsi_acquire_eu, flags, status, data, 4);
  end;
end;
%endif
