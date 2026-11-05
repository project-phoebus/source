%if scsi_mailbox_ctlr %then
{ SCSI_$DO_SYS_DEVICE_CMD - pass a command to a system device's
  routine.

  Image addresses:
    sau7  0x3C4B96D8  SCSI_$DO_SYS_DEVICE_CMD

  - With the mailbox host adapter: the bus and target checked as
    SCSI_$SETUP does; the record in use for them must be a system
    device's with a command routine, which gets the twelve arguments.

  Status stored:
    status_$ok: the routine was called (it stores its own)
    status_$scsi_bad_parameter: the bus or the target out of range
    status_$scsi_device_in_use: the target is the adapter's
    status_$scsi_bus_not_present: no bus, or not bus 0
    status_$scsi_not_system_device: no system device there
    status_$scsi_illegal_sys_device_cmd: it has no routine
}

procedure scsi_$do_sys_device_cmd(in bus: integer; in target: integer;
                                  var arg3: univ_ptr; var arg4: univ_ptr;
                                  var arg5: univ_ptr; var arg6: univ_ptr;
                                  var arg7: univ_ptr; var arg8: univ_ptr;
                                  var arg9: univ_ptr; var arg10: univ_ptr;
                                  var arg11: univ_ptr;
                                  out status: status_$t);
var
  b: integer;
  tg: integer;
  i: integer;
  t: scsi_tinfo_ptr_t;
  cmd_proc: scsi_$sys_cmd_proc_t;
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
    ml_$exclusion_start(scsi_$exclusion_lock);
    t := nil;
    for i := 0 to scsi_max_dev do
      with scsi_$tinfo_list[i] do
        if (scsi_tf_in_use in flags) and (bus = b) and (target = tg) then
        begin
          if scsi_tf_sys in flags then
            t := addr(scsi_$tinfo_list[i]);
          exit;
        end;
    if t = nil then begin
      ml_$exclusion_stop(scsi_$exclusion_lock);
      status.all := status_$scsi_not_system_device;
      return;
    end;
    cmd_proc := t^.sys_proc;
    ml_$exclusion_stop(scsi_$exclusion_lock);
    if cmd_proc = nil then begin
      status.all := status_$scsi_illegal_sys_device_cmd;
      return;
    end;
    cmd_proc^(bus, target, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10,
              arg11, status);
  end;
end;
%else
{ SCSI_$DO_SYS_DEVICE_CMD - pass a command to a system device's routine.

  Image addresses:
    sau9  0x3C4A7144  SCSI_$DO_SYS_DEVICE_CMD

  - The routine SCSI_$SET_SYS_DEVICE gave the device gets this
    routine's twelve arguments as they came, and stores the status.

  Status stored:
    status_$ok: before the routine's own
    status_$scsi_bus_not_present: no bus, or a bus other than 0
    status_$scsi_bad_parameter: a bus above 3 or a target above 7
    status_$scsi_device_in_use: the controller's id
    status_$scsi_not_system_device: the device is not a system device
    status_$scsi_illegal_sys_device_cmd: the device has no routine
}

procedure scsi_$do_sys_device_cmd(in bus: integer; in target: integer;
                                  var arg3: univ_ptr; var arg4: univ_ptr;
                                  var arg5: univ_ptr; var arg6: univ_ptr;
                                  var arg7: univ_ptr; var arg8: univ_ptr;
                                  var arg9: univ_ptr; var arg10: univ_ptr;
                                  var arg11: univ_ptr;
                                  out status: status_$t);
var
  b: integer;
  t: integer;
  tgt: scsi_target_ptr_t;
  cmd_proc: scsi_$sys_cmd_proc_t;
begin
  b := bus;
  t := target;
  status.all := status_$ok;
  if not scsi_$present then begin
    status.all := status_$scsi_bus_not_present;
    return;
  end;
  if (pinteger(b) > scsi_max_bus) or else (pinteger(t) > scsi_host_id) then begin
    status.all := status_$scsi_bad_parameter;
    return;
  end;
  if t = scsi_host_id then begin
    status.all := status_$scsi_device_in_use;
    return;
  end;
  if b <> 0 then begin
    status.all := status_$scsi_bus_not_present;
    return;
  end;
  ml_$exclusion_start(scsi_$exclusion_lock);
  tgt := addr(scsi_$cb[b].target[t]);
  if not tgt^.sys_device or else (tgt^.allocated <> true) then begin
    ml_$exclusion_stop(scsi_$exclusion_lock);
    status.all := status_$scsi_not_system_device;
    return;
  end;
  cmd_proc := tgt^.sys_cmd_proc;
  ml_$exclusion_stop(scsi_$exclusion_lock);
  if cmd_proc = nil then begin
    status.all := status_$scsi_illegal_sys_device_cmd;
    return;
  end;
  cmd_proc^(bus, target, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10,
            arg11, status);
end;
%endif
