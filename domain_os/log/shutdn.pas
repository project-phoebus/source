{ LOG_$SHUTDN - log the shutdown and let go of the log page.

  Image addresses:
    sau2  0x00E1758C  LOG_$SHUTDN
    sau8  0x03C184FC  LOG_$SHUTDN

  - An open log gets a shutdown entry, loses LOG_$LOGFILE_PTR, and is
    unwired, unmapped and unlocked, the statuses not looked at.
  - The low-memory copy's magic is cleared, so the next LOG_$INIT does
    not add it again.

  Status stored: none.
}

procedure log_$shutdn;
var
  saved_ptr: log_$page_ptr_t;
  status: status_$t;
begin
  if log_$logfile_ptr = nil then return;

  { the shutdown entry, no data }
  log_$add(log_$type_shutdown, 0, 0);

  { LOG_$ADD writes nothing from here on }
  saved_ptr := log_$logfile_ptr;
  log_$logfile_ptr := nil;

  { unwire, unmap, unlock }
  wp_$unwire(wired_handle);
  mst_$unmap_privi(1, uid_$nil, integer32(saved_ptr), log_$buffer_size, 0,
                   status);
  discard(file_$unlock(log_$logfile_uid, 4, status));

  log_$last_entry.magic := 0;
end;
