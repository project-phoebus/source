{ RESET_DRIVE - reset the tape controller, or crash.

  Image addresses:
    sau5  0x00E771B2  RESET_DRIVE

  - Up to three tries of the reset command and a 480-tick wait (no
    quit); success or a warning ends it, as does "controller timeout".
  - Three failures with a positive status code other than "controller
    timeout" crash the system with that status.

  Status stored: none.
}

procedure reset_drive;
var
  i: integer;
  status: status_$t;
begin
  ct_reading := true;
  for i := 1 to 3 do begin
    status.all := do_ctl_cmd(ct_cmd_reset, ct_count_unlocked);
    if status.all = 0 then
      status.all := ct_wait(480, false);
    if status.code <= 0 then
      return;
    if status.all = status_$ct_controller_timeout then
      exit;
  end;
  if (status.code > 0)
     and then (status.all <> status_$ct_controller_timeout) then
    crash_system(status);
end;
