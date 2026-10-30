{ ethernet_check_status - crash the system on a status that is not ok.

  Image addresses:
    sau9  0x3C480442  ethernet_check_status

  - The status is passed by value; its copy is what the crash reports.
}

procedure ethernet_check_status(status: status_$t); internal;
begin
  if status.all <> status_$ok then
    crash_system(status);
end;
