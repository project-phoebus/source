{ OS_$SHUTDOWN - shut the node down.

  Image addresses:
    sau2  0x00E6D476  OS_$SHUTDOWN
    sau3  0x00E6D850  OS_$SHUTDOWN
    sau4  0x0F876F72  OS_$SHUTDOWN
    sau5  0x00E6EB52  OS_$SHUTDOWN
    sau6  0x78075FDA  OS_$SHUTDOWN
    sau7  0x3C480952  OS_$SHUTDOWN
    sau8  0x03C7681A  OS_$SHUTDOWN
    sau9  0x3C474082  OS_$SHUTDOWN

  - A process other than process 1 must be the locksmith (its current
    SIDs' user RGYC_$G_LOCKSMITH_UID); otherwise, or if its SIDs cannot
    be read, the routine returns.
  - It does not return otherwise: it ends by crashing the system with
    the volumes' status.
  - `crash_reboot': with good volumes, a good status and OS_$INIT's
    restart code, it restarts the node with that code instead.
  - `smd_display_memory' stops the display after the calendar,
    `shutdown_kbd_mode' resets the keyboard's mode.
  - VOLX_$SHUTDOWN runs twice, the first result dropped; the two
    MST_$WIRE_AREA calls share one page list.
  - With `pbu_driver', PBU_$SHUTDOWN's status is cleared.
  - `fpa_board': the accelerator's save-area base is cleared after the
    FPU's.
  - Other SAUs' parts (base/config.ins.pas): the color boards stopped;
    with `power_down', after a good shutdown and a power-off request,
    the disks spun down and the interrupts disabled.

  Status stored: none.
}

procedure os_$shutdown(status: status_$t);
var
  status_l: status_$t;
  volx_status: status_$t;
  svc_value: network_$service_t;
  wire_pages: array[1..100] of integer32;
  original_sids: acl_sid_block_t;
  current_sids: acl_sid_block_t;
  line: array[1..100] of char;
  out_len: integer;
  wire_count: integer;
  i: integer;
  wait_delay: static time_$clock_t := [high := 3, low := 0];
                                          { .DATA +0x10 }
begin
  if proc1_$current <> 1 then begin
    acl_$get_re_sids(original_sids, current_sids, status_l);
    if status_l.all <> status_$ok then
      return;
    if current_sids.user_sid <> rgyc_$g_locksmith_uid then
      return;
  end;

  time_$wait(time_$relative, wait_delay, status_l);
  crash_show_string('Beginning shutdown sequence...%.');
  os_$shutting_down_flag := true;

  network_$dismiss_request_servers;
  proc2_$shutdown;
  route_$shutdown;
  pacct_$shutdn;
  log_$shutdn;
  audit_$shutdown;
  hint_$shutdn;

  if not network_$really_diskless then
    cal_$shutdown(status_l);
%if smd_display_memory %then
  smd_$shutdown;
%endif
%if shutdown_kbd_mode %then
  term_$control(0, term_$opt_kbd_mode, 0, status_l);
%endif

%if gpu_driver and not color2_shutdown_in_smd %then
  { the color boards }
  case smd_$graphic_device_id of
    smd_gdev_color2, smd_gdev_color3:
      color2_$shutdown;
    otherwise
%if color_board %then
      color_$shutdown;
%endif
  end;
%else
%if color_board %then
  color_$shutdown;
%endif
%endif
%if pbu_driver %then
  pbu_$shutdown(volx_status);
%endif

%if not shutdown_keeps_fp_savep %then
  fp_$savep := nil;
%endif
%if fpa_board %then
  fpa_$savep := nil;
%endif

  { wire the shutdown-wired code, then data }
  mst_$wire_area(addr(os_proc_shutwired), addr(os_proc_shutwired_end),
                 wire_pages, 100, wire_count);
  mst_$wire_area(addr(os_data_shutwired), addr(os_data_shutwired_end),
                 wire_pages, 100, wire_count);

  file_$priv_unlock_all(0);
  pmap_$shutting_down_flag := true;
  area_$shutdown;

  volx_status.all := status_$ok;
  if not network_$really_diskless then begin
    discard(volx_$shutdown);
    volx_status.all := volx_$shutdown;
    if volx_status.all <> status_$ok then begin
      vfmt_$encode2('shutdown failed. status = %lh%%%.', line, 100,
                    out_len, volx_status, 0);
      crash_show_string(line);
    end;
  end;

  crash_show_string('Shutdown successful%');

  svc_value.service := [];
  svc_value.remote_pool := 0;
  network_$set_service(network_op_set_value, svc_value, status_l);

%if power_down %then
  { the power down }
  if volx_status.all = status_$ok then
    if mmu_$power_off then begin
      crash_show_string('Beginning power down sequence...%$');
      if not network_$really_diskless then
        disk_$spin_down;
      disable;
%if vme_power_off %then
      vme_ctl.ctl_30.power := false;
%endif
%if power_off_csr %then
      mmu_$set_csr(os_csr_power_off);
%endif
    end;
%endif

  { a delay }
  for i := 0 to 2000 do
    status_l.all := status_l.all * status_l.all;

%if crash_reboot %then
  { after a good volume shutdown, the caller's status; a good one with
    a restart code left by OS_$INIT restarts the node through the PROM }
  if volx_status.all = status_$ok then
    volx_status := status;
  if (volx_status.all <> status_$ok) or else (restart_code = 0) then
    crash_system(volx_status)
  else
    crash(restart_code, 0);
%else
  crash_system(volx_status);
%endif
end;
