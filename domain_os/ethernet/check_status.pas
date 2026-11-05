{ ethernet_check_status - crash the system on a status that is not ok.

  Image addresses:
    sau6  0x78086842  ethernet_check_status
    sau7  0x3C491042  ethernet_check_status
    sau8  0x03C84842  ethernet_check_status
    sau9  0x3C480442  ethernet_check_status

  - The status is passed by value; its copy is what the crash reports.
}

procedure ethernet_check_status(status: status_$t); internal;
begin
  if status.all <> status_$ok then
    crash_system(status);
end;
