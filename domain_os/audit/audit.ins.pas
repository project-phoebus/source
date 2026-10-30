{ audit/audit.ins.pas - AUDIT_ (the audit trail), for the Domain Pascal
  tree.

  The statuses, the audit list file's records, the event record and the
  hash chains, the AUDIT_WIRED module's two flags, the AUDIT module's
  ten event UIDs and the AUDIT_ globals' headings (map order).

  GET_WIRED is declared in misc/misc.ins.pas, the module-local routines
  in audit/audit.pas; the five event loggers audit/log_*_op.pas are
  DIR's (audit/README.md).

  Include base/base.ins.pas, ec/ec.ins.pas, ml/ml.ins.pas,
  time/time.ins.pas and acl/acl.ins.pas before it.
}

const
  { The statuses AUDIT stores, stcode.db.10.2 "OS / audit trail manager"
    (subsystem 16#30). }
  status_$audit_excessive_event_types = 16#00300003;
                                          { "excessive event types":
                                            audit_$load_list }
  status_$audit_event_logging_is_disabled = 16#00300004;
                                          { AUDIT_$CONTROL }
  status_$audit_invalid_action_code = 16#00300007;
                                          { AUDIT_$CONTROL }
  status_$audit_permission_denied = 16#00300008;
                                          { "permission to perform action
                                            is denied": AUDIT_$CONTROL }
  status_$audit_could_not_find_audit_event_list = 16#0030000C;
                                          { AUDIT_$ADMINISTRATOR }
  status_$audit_event_logging_already_started = 16#0030000E;
                                          { audit_$start_logging }
  status_$audit_event_logging_already_stopped = 16#0030000F;
                                          { audit_$stop_logging }
  status_$audit_event_list_not_current_format = 16#00300010;
                                          { "event list format is not the
                                            current version":
                                            audit_$load_list }
  status_$audit_logging_is_enabled = 16#00300011;
                                          { AUDIT_$CONTROL; not in
                                            stcode.db.10.2 (the name from
                                            the SR10.4 table) }

  { AUDIT_$CONTROL's commands.  The names for 4 and 5 follow the table
    (4 lowers the count, 5 raises it). }
  audit_ctrl_load_list = 0;
  audit_ctrl_flush = 1;
  audit_ctrl_start = 2;
  audit_ctrl_stop = 3;
  audit_ctrl_resume_self = 4;
  audit_ctrl_suspend_self = 5;
  audit_ctrl_is_enabled = 6;

  { The members of the list's flag word.  With member 0 set every event
    is logged (the name says the opposite; audit/README.md). }
  audit_flag_selective = 0;
  audit_flag_timeout = 1;

  { The largest event data AUDIT_$LOG_EVENT_S copies. }
  audit_max_data_size = 2048;

type
  { The list's flag word (above). }
  audit_$flags_t = set of 0..15;

  { The AUDIT module's WIRED_DATA object, GET_WIRED's static
    (misc/get_wired.pas, 0x20 bytes): an eventcount at +0 and the
    exclusion lock at +0x0C. }
  audit_$wired_t = record
    ec: ec_$eventcount_t;                 { 0x00 }
    lock: ml_$exclusion_t;                { 0x0C }
  end;
  audit_$wired_ptr_t = ^audit_$wired_t;

  { A node of the audit list's hash chains, 12 bytes: its next at +0, the
    UID at +4. }
  audit_$hash_node_ptr_t = ^audit_$hash_node_t;
  audit_$hash_node_t = record
    next: audit_$hash_node_ptr_t;         { 0x00 }
    uid: uid_$t;                          { 0x04 }
  end;
  { A pointer to a chain's link cell (a bucket, or a node's next at +0). }
  audit_$link_ptr_t = ^audit_$hash_node_ptr_t;

  { The audit list file's image, as mapped (the entries after the
    header, from +0x10 in steps of 8). }
  audit_$list_t = record
    list_uid: uid_$t;                     { 0x00 }
    timeout_units: integer;               { 0x08 }
    version: integer;                     { 0x0A }
    entry_count: integer;                 { 0x0C }
    flags: audit_$flags_t;                { 0x0E }
    entries: array[1..256] of uid_$t;     { 0x10 }
  end;
  audit_$list_ptr_t = ^audit_$list_t;

  { The node field of an event record, a longword of two packed fields
    (the node in the upper 20 bits, at bit 12). }
  audit_$node_field_t = packed record
    node: 0..16#FFFFF;                    { bits 31..12 }
    low: 0..16#FFF;                       { bits 11..0 }
  end;

  { An event record as AUDIT_$LOG_EVENT_S writes it into the mapped log
    (the data from +0x46).  The size is read zero-extended: pinteger. }
  audit_$event_rec_t = record
    record_size: pinteger;                { 0x00 }
    version: integer;                     { 0x02 }
    sid: acl_sid_block_t;                 { 0x04 }
    event_flags: pinteger;                { 0x28 }
    node_id: audit_$node_field_t;         { 0x2A }
    event_uid: uid_$t;                    { 0x2E }
    status: status_$t;                    { 0x36 }
    timestamp: time_$clock_t;             { 0x3A }
    upid: integer;                        { 0x40 }
    uppid: integer;                       { 0x42 }
    upgid: integer;                       { 0x44 }
    data: array[0..audit_max_data_size] of char;
                                          { 0x46 }
  end;
  audit_$event_rec_ptr_t = ^audit_$event_rec_t;

  { An event UID as DIR's event loggers build it (the class word 4, the
    event's word, a longword 0).  The second variant is the UID the call
    passes (a variant record, so the formal stays uid_$t). }
  { The 44-byte protection data DIR's audit_$log_prot_op copies into its
    event record as eleven longwords. }
  audit_$prot_data_t = array[1..11] of integer32;

  audit_$event_uid_t = record
    case integer of
      1: (uid: uid_$t);                   { 0x00 }
      2: (event_class: integer;           { 0x00 }
          audit_subtype: integer;         { 0x02 }
          reserved: integer32);           { 0x04 }
  end;

  { The event data the callers pass (by address, its length beside it). }
  audit_$event_data_t = array[1..audit_max_data_size] of char;

var
  { AUDIT_$CORRUPTED and AUDIT_$ENABLED (map symbols, the AUDIT_WIRED data
    segment, WIRED_DATA; defined in audit/audit_wired.pas): booleans,
    tested by their sign. }
  audit_$corrupted: extern boolean;
  audit_$enabled: extern boolean;

  { The ten event UIDs of the AUDIT module's .DATA block (map symbols,
    defined in audit/audit.pas at +0x148..+0x197). }
  audit_$scsi_acquire_eu: extern uid_$t;
  audit_$acquire_ct_eu: extern uid_$t;
  audit_$acquire_mt_eu: extern uid_$t;
  audit_$acquire_lpr_eu: extern uid_$t;
  audit_$dismount_lv_eu: extern uid_$t;
  audit_$mount_lv_eu: extern uid_$t;
  audit_$assign_disk_eu: extern uid_$t;
  audit_$mount_disk_eu: extern uid_$t;
  audit_$enter_subs_eu: extern uid_$t;
  audit_$set_sid_eu: extern uid_$t;

  { The AUDIT module's code markers AUDIT_$PROC_START (AUDIT_$INIT's
    address) and AUDIT_$PROC_END (the map's second AUDIT .TEXT segment,
    four zero bytes), and its data markers AUDIT_$DATA_START (also
    PEB_$WIRED_DATA_END) and AUDIT_$DATA_END (NETLOG_$DATA_START):
    labels the build places, as netlog/netlog.ins.pas's. }
  audit_$proc_start: extern char;
  audit_$proc_end: extern char;
  audit_$data_start: extern char;
  audit_$data_end: extern char;

{ AUDIT_$INIT - set up the audit trail at boot. }
procedure audit_$init; extern;

{ AUDIT_$SHUTDOWN - stop the audit trail at shutdown. }
procedure audit_$shutdown; extern;

{ AUDIT_$IS_PROCESS_AUDITED - whether the current process is audited. }
function audit_$is_process_audited: boolean; extern;

{ AUDIT_$SUSPEND - suspend auditing of the current process.
  AUDIT_$RESUME - resume auditing of the current process. }
procedure audit_$suspend; extern;
procedure audit_$resume; extern;

{ AUDIT_$LOG_EVENT - log an event for the current process. }
procedure audit_$log_event(in event_uid: uid_$t; in event_flags: pinteger;
                           in status: status_$t;
                           in data: univ audit_$event_data_t;
                           in data_len: pinteger); extern;

{ AUDIT_$LOG_EVENT_S - log an event with a given SID block. }
procedure audit_$log_event_s(in event_uid: uid_$t; in event_flags: pinteger;
                             in sid: acl_sid_block_t; in status: status_$t;
                             in data: univ audit_$event_data_t;
                             in data_len: pinteger); extern;

{ AUDIT_$SERVER - the audit server process. }
procedure audit_$server; extern;

{ AUDIT_$ADMINISTRATOR - whether the caller is an audit administrator. }
function audit_$administrator(out status: status_$t): boolean; extern;

{ AUDIT_$CONTROL - the audit trail's control call. }
procedure audit_$control(in command: integer; out status: status_$t);
  extern;

{ AUDIT_$INHERIT_AUDIT - give a child process its parent's suspension
  count. }
procedure audit_$inherit_audit(in child_pid: integer;
                               out status_ret: status_$t); extern;
