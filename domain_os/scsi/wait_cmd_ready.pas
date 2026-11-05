{ scsi_wait_cmd_ready - wait for the host adapter's command port.

  Image addresses:
    sau7  0x3C4B81B4  scsi_wait_cmd_ready (module-local)

  - Polls the status port for ready, 160000 times at most.

  Returns:
    false: the port is ready
    true: it did not become ready

  Status stored: none.
}

function scsi_wait_cmd_ready(var cb: scsi_mb_cb_t): boolean; internal;
var
  i: integer32;
begin
  i := 0;
  repeat
    if (cb.regs^.cmd & scsi_mb_stat_ready) <> 0 then begin
      scsi_wait_cmd_ready := false;
      return;
    end;
    i := i + 1;
  until i = 160000;
  scsi_wait_cmd_ready := true;
end;
