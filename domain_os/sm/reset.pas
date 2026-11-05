{ sm_$reset - reset the storage module controller and its drives.

  Image addresses:
    sau3  0x00E6DB52  sm_$reset (module-local)
    sau4  0x0F8772CE  sm_$reset (module-local)
    sau5  0x00E6EEAA  sm_$reset (module-local)
    sau6  0x7807634E  sm_$reset (module-local)

  - The controller is probed and reset five times, and each drive then
    reset; the probe's and the drives' statuses are not returned.
  - A PBU_$ENABLE_DEVICE failure crashes the system.  The DCTE argument
    is not read.
  - The first loop does not stop when a reset succeeds.

  Status stored:
    status_$ok: the drives were reset
    sm_$command's status: a drive's reset command failed
}

procedure sm_$reset(dcte: dcte_ptr_t; out status_ret: status_$t);
  internal;
var
  try: integer;
  unit: integer;
  page: ^sm_$page_t;
  en_status: status_$t;
begin
  page := addr(pbu_sm_page);
  for try := 1 to 5 do
    if not testpage(sm_probe_kind, addr(page^.go), sm_$cb.probe) then
      status_ret.all := status_$io_controller_not_in_system
    else begin
      page^.go := sm_$cb.go_ack;
      sm_$cb.busy := 16#FF;
      page^.go := sm_$cb.go_cmd;
      status_ret.all := sm_$wait_ready;
      if status_ret.all = 0 then begin
        pbu_$enable_device(sm_pbu_unit, en_status);
        if en_status.all <> 0 then
          crash_system(en_status);
      end;
    end;

  for unit := 0 to sm_max_unit do begin
    sm_$cb.buf_offset := sm_$page_offset(addr(sm_$cb.drive[unit].params));
    sm_$cb.cmd_word.unit := unit;
    status_ret.all := sm_$command(unit, sm_cmd_reset);
    if status_ret.all <> 0 then
      return;
    status_ret.all := sm_$check_status(unit);
  end;
  status_ret.all := status_$ok;
end;
