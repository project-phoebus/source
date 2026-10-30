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
