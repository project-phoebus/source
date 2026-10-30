{ ring_8025_check_status - crash the system on a status that is not ok.

  Image addresses:
    sau9  0x3C484C68  ring_8025_check_status

  - The status is passed by value; its copy is what the crash reports.
}

procedure ring_8025_check_status(status: status_$t); internal;
begin
  if status.all <> status_$ok then
    crash_system(status);
end;
