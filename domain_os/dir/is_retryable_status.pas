{ dir_$is_retryable_status - whether a failed directory operation may be
  retried elsewhere.

  Image addresses:
    sau2  0x00E4BC26  dir_$is_retryable_status

  - True for "directory not local", "directory not found in pathname",
    "directory object not found", FILE_'s "bad reply received from
    remote node" and "communications problem", and any module 16#11 one.

  Status stored: none.
}

function dir_$is_retryable_status(status: status_$t): boolean; internal;
begin
  dir_$is_retryable_status :=
    (status.all = status_$naming_directory_not_local) or
    (status.all = status_$naming_directory_not_found_in_pathname) or
    (status.all = status_$naming_directory_object_not_found) or
    (status.all = file_$bad_reply_received_from_remote_node) or
    (status.all = file_$comms_problem_with_remote_node) or
    (status.modc = 16#11);
end;
