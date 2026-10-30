{ audit_$close_log - write back, trim, unlock and forget the audit log.

  Image addresses:
    sau2  0x00E7185E  audit_$close_log (module-local)

  - The log is written back and unmapped, the file truncated to the part
    written and unlocked, and the log's UID set to nil.

  Status stored:
    status_$ok: the log was not open
    file_$priv_unlock's status: each step's status overwrites the last
}

procedure audit_$close_log(out status: status_$t); internal;
var
  dtv: time_$clock_t;
  final_size: integer32;
begin
  if audit_$log_file_uid = uid_$nil then
    status.all := status_$ok

  else begin
    audit_$dirty := false;
    file_$fw_file(audit_$log_file_uid, status);
    mst_$unmap_privi(1, uid_$nil, audit_$buffer_base, audit_$buffer_size, 0,
                     status);
    final_size := audit_$file_offset + audit_$buffer_size -
                  audit_$bytes_remaining;
    file_$truncate(audit_$log_file_uid, final_size, status);
    discard(file_$priv_unlock(audit_$log_file_uid, audit_$lock_id, 4, 0,
                              false, 0, 0, 0, dtv, status));
    audit_$log_file_uid := uid_$nil;
  end;
end;
