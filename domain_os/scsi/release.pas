%if scsi_mailbox_ctlr %then
{ SCSI_$RELEASE - release a device.

  Image addresses:
    sau7  0x3C4B8E2C  SCSI_$RELEASE

  - With the mailbox host adapter: under scsi_$exclusion_lock the
    device's I/O map region is freed, its wired pages unwired, its
    record freed and the counts of devices set up lowered; the last
    unwires the module's code and data.
  - The device's number is read from the record before the handle's
    status is tested.

  Status stored:
    scsi_get_tinfo's status: in either case
}

procedure scsi_$release(in handle: scsi_$handle_t; out status: status_$t);
var
  t: scsi_tinfo_ptr_t;
  dev: integer;
  cb: scsi_mb_cb_ptr_t;
  st: status_$t;
begin
  t := scsi_get_tinfo(handle.all, status);
  dev := t^.dev;
  if status.all <> status_$ok then
    return;
  cb := addr(scsi_$cb[t^.bus]);
  ml_$exclusion_start(scsi_$exclusion_lock);
  if scsi_tf_wired in t^.flags then
    scsi_free_iova(t^, st);
  scsi_unwire_all(dev);
  t^.flags := t^.flags - [scsi_tf_in_use, scsi_tf_sys];
  cb^.open_count := cb^.open_count - 1;
  scsi_open_count := scsi_open_count - 1;
  if scsi_open_count = 0 then
    scsi_unwire_driver;
  ml_$exclusion_stop(scsi_$exclusion_lock);
end;
%else
{ SCSI_$RELEASE - release a device.

  Image addresses:
    sau9  0x3C4A6290  SCSI_$RELEASE

  - Waits for each of the device's requests, pending then done (with no
    quit, up to 1000000 ticks each), with the locks released; then
    unwires every page the device has wired and gives the target up.
  - The driver's own pages are unwired with the last device, while no
    target has answered a selection yet.
  - The test for the controller's own id (7) follows the handle check.

  Status stored:
    status_$ok: the device was released
    status_$scsi_bus_not_present: no bus, or a bus other than 0
    status_$scsi_bad_handle: the handle names no device or an old one
    status_$scsi_device_in_use: the controller's id
    status_$scsi_device_not_acquired: the device is not set up
}

procedure scsi_$release(in handle: scsi_$handle_t; out status: status_$t);
var
  bus: integer;
  target: integer;
  dev: integer;
  tgt: scsi_target_ptr_t;
  cb: scsi_cb_ptr_t;
  token: integer;
  req: scsi_req_ptr_t;
  result: scsi_$result_t;
  count: integer;
  st: status_$t;
begin
  status.all := status_$ok;
  if not scsi_$present then begin
    status.all := status_$scsi_bus_not_present;
    return;
  end;
  if (handle.bus > scsi_bus_count - 1)
     or else (handle.target > scsi_max_target) then begin
    status.all := status_$scsi_bad_handle;
    return;
  end;
  bus := handle.bus;
  target := handle.target;
  dev := bus * 8 + target;
  if target = scsi_host_id then begin
    status.all := status_$scsi_device_in_use;
    return;
  end;
  if bus <> 0 then begin
    status.all := status_$scsi_bus_not_present;
    return;
  end;

  ml_$exclusion_start(scsi_$exclusion_lock);
  tgt := addr(scsi_$cb[bus].target[target]);
  if tgt^.allocated = false then begin
    ml_$exclusion_stop(scsi_$exclusion_lock);
    status.all := status_$scsi_device_not_acquired;
    return;
  end;
  if tgt^.gen <> handle.gen then begin
    ml_$exclusion_stop(scsi_$exclusion_lock);
    status.all := status_$scsi_bad_handle;
    return;
  end;
  cb := addr(scsi_$cb[bus]);

  { Wait for the device's requests. }
  token := ml_$spin_lock(scsi_lock);
  while tgt^.pend_head <> nil do begin
    req := tgt^.pend_head;
    ml_$spin_unlock(scsi_lock, token);
    ml_$exclusion_stop(scsi_$exclusion_lock);
    discard(scsi_$wait(handle, 1000000, false, req^.result.id, 1, result,
                       count, st));
    ml_$exclusion_start(scsi_$exclusion_lock);
    token := ml_$spin_lock(scsi_lock);
  end;
  while tgt^.done_head <> nil do begin
    req := tgt^.done_head;
    ml_$spin_unlock(scsi_lock, token);
    ml_$exclusion_stop(scsi_$exclusion_lock);
    discard(scsi_$wait(handle, 1000000, false, req^.result.id, 1, result,
                       count, st));
    ml_$exclusion_start(scsi_$exclusion_lock);
    token := ml_$spin_lock(scsi_lock);
  end;
  ml_$spin_unlock(scsi_lock, token);

  scsi_unwire_all(dev);
  tgt^.allocated := false;
  tgt^.sys_device := false;
  cb^.open_count := cb^.open_count - 1;
  scsi_open_count := scsi_open_count - 1;
  if scsi_$cb[handle.bus].never_selected and then (scsi_open_count = 0) then
    scsi_unwire_driver;
  ml_$exclusion_stop(scsi_$exclusion_lock);
end;
%endif
