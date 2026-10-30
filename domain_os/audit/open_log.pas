{ audit_$open_log - open, lock and map the audit log.

  Image addresses:
    sau2  0x00E716CC  audit_$open_log (module-local)

  - The log's file, `node_data/audit/audit_log, is created when it is
    not there, made unstructured, write-locked, and mapped (32K) from
    its end.
  - On a failure the lock is dropped and the log's UID is nil again.

  Status stored:
    status_$ok: the log was open already, or is now
    the callees' statuses: otherwise
}

{ TODO(pascal) 8 frame bytes of audit_$open_log no object explains

  Between dtv and rights the SAU2 frame has 8 bytes no instruction
  addresses; the stand-ins unused_c4 and unused_c8 hold them (two
  longwords: a file-size local, held in no register here, would be
  one). }

procedure audit_$open_log(out status: status_$t); internal;
var
  loc: file_$obj_loc_t;
  attrs: file_$attributes_t;
  dtv: time_$clock_t;
  unused_c4: integer32;                   { stand-in }
  unused_c8: integer32;                   { stand-in }
  rights: integer;
begin
  if audit_$log_file_uid <> uid_$nil then
    status.all := status_$ok

  else begin
    name_$resolve('`node_data/audit/audit_log', 26, audit_$log_file_uid,
                  status);
    if status.all = name_$not_found then
      name_$cr_file('`node_data/audit/audit_log', 26, audit_$log_file_uid,
                    status);

    if status.all = status_$ok then begin
      file_$set_type(audit_$log_file_uid, unstruct_$uid, status);
      if status.all = status_$ok then begin
        file_$get_attributes(audit_$log_file_uid, 4, 16#90, loc, attrs,
                             status);
        if status.all = status_$ok then begin
          audit_$file_offset := attrs.length;
          file_$priv_lock(audit_$log_file_uid, 0, 1, 4, false, 0, 0, 0, 0,
                          0, 0, 0, audit_$lock_id, rights, status);
          if status.all = status_$ok then begin
            audit_$buffer_base := integer32(mst_$maps(0, true,
              audit_$log_file_uid, audit_$file_offset, 16#8000, 16#16, 0,
              true, audit_$buffer_size, status));
            if status.all <> status_$ok then
              discard(file_$priv_unlock(audit_$log_file_uid, audit_$lock_id,
                                        4, 0, false, 0, 0, 0, dtv, status))
            else begin
              audit_$write_ptr := audit_$buffer_base;
              audit_$bytes_remaining := audit_$buffer_size;
              audit_$dirty := false;
            end;
          end;
        end;
      end;
    end;

    if status.all <> status_$ok then begin
      audit_$log_file_uid := uid_$nil;
      audit_$write_ptr := 0;
      audit_$file_offset := 0;
      audit_$bytes_remaining := 0;
      audit_$dirty := false;
    end;
  end;
end;
