{ ct_status_cmd - give the tape drive the read status command.

  Image addresses:
    sau8  0x03C7A1F0  ct_status_cmd (module-local)

  - The command byte is written with the request, and once the adapter
    shows ready the request is dropped with the interrupts off; the
    drive must then drop ready within 52800 polls.
  - The result is a status.

  Status stored: none.
}

function ct_status_cmd: integer32; internal;
var
  timeout: integer32;
  status: status_$t;
  i: integer32;
  ready: boolean;
begin
  timeout := 16;
  status.all := status_$ok;
  ct_regs^.data := ct_cmd_read_status;
  ct_regs^.ctl := ct_ctl_request;
  ct_ignore_exception := true;
  if ct_wait_ready(timeout, status) then begin
    ct_state := ct_state_none;
    disable;
    ct_regs^.ctl := 0;
    for i := 1 to 52800 do
      if ct_regs^.stat.not_ready then begin
        ready := false;
        exit;
      end
      else
        ready := true;
    enable;
    if ready then
      ct_status_cmd := status_$ct_controller_timeout
    else
      ct_status_cmd := 0;
  end
  else
    ct_status_cmd := status.all;
end;
