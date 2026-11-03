{ LOG_$UPDATE - hand back the wired page's handle when the log has
  changed.

  Image addresses:
    sau2  0x00E1760C  LOG_$UPDATE
    sau8  0x03C1857C  LOG_$UPDATE

  - The result is the wired page's handle when the log is open and
    dirty (dirty_flag then cleared), else 0.
  - The low-memory copy's magic is cleared on both paths.

  Status stored: none.
}

function log_$update: integer32;
begin
  if (log_$logfile_ptr <> nil) and then dirty_flag then begin
    log_$update := wired_handle;
    dirty_flag := false;
  end
  else
    log_$update := 0;

  log_$last_entry.magic := 0;
end;
