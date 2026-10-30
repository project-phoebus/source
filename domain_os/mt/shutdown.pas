{ mt_$shutdown - shut the magnetic tape controller down and unwire the
  driver's pages.

  Image addresses:
    sau5  0x00E75700  mt_$shutdown

  - The controller is stopped only when its PBU device is enabled
    (PBU_$DISABLE_DEVICE's status ignored), and the pages unwired only
    when wired; the list's count is left as it is.

  Status stored: none.
}

procedure mt_$shutdown; internal;
var
  status: status_$t;
  i: integer;
begin
  with mt_$scb do begin
    if mt_scb_enabled in flags.bits then begin
      pbu_mt_page.control := mt_ctl_shutdown;
      flags.state := 0;
      pbu_$disable_device(mt_pbu_unit, status);
    end;
    if mt_scb_wired in flags.bits then begin
      for i := 1 to mt_wired_count do
        wp_$unwire(mt_wired[i]);
      flags.bits := flags.bits - [mt_scb_wired];
    end;
  end;
end;
