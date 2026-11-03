{ LOG_$INIT - open the system error log, and log what the last boot left.

  Image addresses:
    sau2  0x00E30048  LOG_$INIT
    sau2  0x00E2FF7C  log_$check_op_status (nested)
    sau4  0x0F8335C4  LOG_$INIT
    sau4  0x0F8334F8  log_$check_op_status (nested)
    sau8  0x03C32FB8  LOG_$INIT

  - `node_data/system_logs/sys_error_log is resolved (created if need
    be), mapped, locked and wired, an empty page given head 0 and tail
    1; only then is LOG_$LOGFILE_PTR set.
  - A failed step prints a warning (the nested log_$check_op_status) and
    leaves the log closed.
  - The entry the last boot was writing, the crash record (type 5) and
    the init entry (type 0) are then added.
  - The last entry is added again, its size in words given as the byte
    count.

  Status stored: none.
}

{ TODO(pascal) 12 frame bytes unaddressed (stand-in unused_58)

  The 12 bytes at the bottom of the frame that no instruction addresses
  (the stand-in unused_58).  Added to the survey in tty/k_flush_input.pas. }

[section(os_init_proc, os_init_data)]
procedure log_$init;
const
  { 36 characters, no terminator (the next byte begins the longword
    36).  The leading ` is the node's entry directory. }
  log_$logfile_path = '`node_data/system_logs/sys_error_log';
  log_$logfile_path_len = 36;
var
  desc: file_$obj_loc_t;
  cattr: ast_$common_attr_t;
  page: log_$page_ptr_t;
  map_out: integer32;
  status: status_$t;                      { read by the nested routine }
  lock_out: integer32;
  is_empty: boolean;
  unused_58: array[1..3] of integer32;    { the stand-in (TODO) }

  { log_$check_op_status - warn when a step of LOG_$INIT failed.

    - When the status's code is not 0, the message "Warning: Status
      <status>, Unable to <op> <path> -- error logging disabled." is
      printed in three VFMT_$WRITE2 calls and the result is true.
    - Only the code half is tested: a status with code 0 passes whatever
      its high word.
    - Nested in LOG_$INIT, whose status it reads.

    Status stored: none. }

  function log_$check_op_status(in op: univ vfmt_$string_t): boolean;
  begin
    if status.code <> 0 then begin
      vfmt_$write2('%/%/Warning: Status %lh, Unable to %$', status, 0);
      vfmt_$write2(op, 0, 0);
      vfmt_$write2(' %a -- error logging disabled.%.', log_$logfile_path,
                   log_$logfile_path_len);
      log_$check_op_status := true;
    end
    else
      log_$check_op_status := false;
  end;

begin
  { find the log file, or make it }
  name_$resolve(log_$logfile_path, log_$logfile_path_len, log_$logfile_uid,
                status);
  if status.all = name_$not_found then begin
    name_$cr_file(log_$logfile_path, log_$logfile_path_len,
                  log_$logfile_uid, status);
    if log_$check_op_status('create%$') then return;
  end;
  if log_$check_op_status('resolve%$') then return;

  { its attributes }
  desc.uid := log_$logfile_uid;
  desc.flags := desc.flags - [6];
  ast_$get_common_attributes(desc, 2, cattr, status);
  if log_$check_op_status('get_attributes%$') then return;
  is_empty := cattr.length = 0;

  { map the first page }
  page := mst_$maps(0, true, log_$logfile_uid, 0, log_$buffer_size, 16#16,
                    0, is_empty, map_out, status);
  if log_$check_op_status('map%$') then return;

  { lock the file }
  file_$lock(log_$logfile_uid, 0, 4, false, lock_out, status);
  if log_$check_op_status('lock%$') then return;

  { an empty page: head 0, tail 1 }
  if is_empty or else ((page^.head = 0) and (page^.tail = 0)) then begin
    page^.head := 0;
    page^.tail := 1;
    dirty_flag := true;
  end;

  { wire it }
  wired_handle := mst_$wire(integer32(page), status);
  if log_$check_op_status('wire%$') then return;

  { LOG_$ADD writes from here on }
  log_$logfile_ptr := page;

  { the entry being written when the system went down, with its own
    time }
  if log_$last_entry.magic = log_$pending_magic then begin
    log_$add(log_$last_entry.entry_type, log_$last_entry.data,
             log_$last_entry.size);
    current_entry_ptr^.timestamp := log_$last_entry.timestamp;
    log_$last_entry.magic := 0;
  end;

  { the crash record; its magic cleared first }
  if crash_$record.magic = log_$pending_magic then begin
    crash_$record.magic := 0;
    log_$add(log_$type_crash, crash_$record.data, 8);
  end;

  { the init entry, no data }
  log_$add(log_$type_init, 0, 0);
end;
