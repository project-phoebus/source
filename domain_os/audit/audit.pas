{ audit/audit.pas - the AUDIT module, the audit trail.

  Image addresses:
    sau2  0x00E2E07C  AUDIT data (WIRED_DATA, 0x20 bytes)
    sau2  0x00E854D8  AUDIT data (.DATA, 0x1AC bytes)
    sau2  0x00EC4800  AUDIT_LIST overlay (0xC00 bytes)

  One compilation unit: the map's AUDIT code segments in WIRED_PROC
  (0x18 bytes: GET_WIRED) and .TEXT (0xE14 bytes: AUDIT_$INIT ..
  AUDIT_$INHERIT_AUDIT and the module-local routines), its data segments
  in WIRED_DATA (0x20 bytes) and .DATA (0x1AC bytes), and the overlay
  AUDIT_LIST (0xC00 bytes).

  GET_WIRED is misc/get_wired.pas, a fragment of this module headed
  `[section(wired_proc, wired_data)]'; the WIRED_DATA block is its
  static (audit/audit.ins.pas audit_$wired_t).  A second .TEXT segment
  of four zero bytes holds the marker AUDIT_$PROC_END, no code.  The
  map's AUDIT_WIRED is another map module, data only
  (audit/audit_wired.pas).

  The heading: the code is .TEXT's and the block .DATA's, the defaults
  (ref 7.1.1), `module audit;'.  The block's objects are module
  variables (ref 7.2.2, Method 2).  AUDIT_$SUSPEND and AUDIT_$RESUME
  address the block by its absolute address, no A5 (cause not known).

  The .DATA block, 0x1AC bytes, zero but the ten event UIDs:

    +0x000  audit_$suspend_count  64 * 2  from 1, by PROC1_$CURRENT
    +0x080  audit_$log_file_uid      8
    +0x088  audit_$buffer_base       4
    +0x08C  audit_$buffer_size       4    MST_$MAPS's map_info
    +0x090  audit_$write_ptr         4

    +0x094  audit_$bytes_remaining   4    compared signed
    +0x098  audit_$file_offset       4
    +0x09C  audit_$dirty             1    boolean
    +0x09D  (3 bytes: the next longword's alignment)
    +0x0A0  audit_$list_uid          8
    +0x0A8  audit_$flags             2    a set (audit/audit.ins.pas)

    +0x0AA  audit_$timeout           2    integer (sign-extended)
    +0x0AC  audit_$list_count        2
    +0x0AE  (2 bytes: the next longword's alignment)
    +0x0B0  audit_$hash_buckets  38 * 4   from 0
    +0x148  AUDIT_$SCSI_ACQUIRE_EU .. AUDIT_$SET_SID_EU  10 * 8, defined

    +0x198  audit_$wired             4
    +0x19C  audit_$lock_id           4    FILE_$PRIV_LOCK's slot_io
    +0x1A0  audit_$server_pid        2
    +0x1A2  audit_$server_running    1    boolean
    +0x1A3  (1 byte: the next longword's alignment)
    +0x1A4  audit_$pool_next         4

    +0x1A8  audit_$pool_limit        4    compared unsigned

  The overlay AUDIT_LIST is a load section with no module segment in
  it, the pages audit_$alloc installs for the hash nodes: written
  `var (audit_list)', as xpd/xpd.pas's XPD_$DATA.

  The routines live in one fragment file each (audit/<name>.pas;
  misc/get_wired.pas for GET_WIRED), in image order.
  audit_$clear_hash_table and audit_$add_to_hash are nested in
  audit_$load_list (load_list.pas).
  The five event loggers audit/log_*_op.pas are DIR's.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/audit/audit.pas.  Check: tools/pascal_check.sh.
}
module audit;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'misc/misc.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'os/os.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'wp/wp.ins.pas';
%include 'mst/mst.ins.pas';
%include 'node/node.ins.pas';
%include 'name/name.ins.pas';
%include 'file/file.ins.pas';
%include 'acl/acl.ins.pas';
%include 'rgyc/rgyc.ins.pas';
%include 'audit/audit.ins.pas';

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above), the routines in
  map order. }
var
  audit_$suspend_count: array[1..64] of integer;   { +0x000, zero }
  audit_$log_file_uid: uid_$t;                     { +0x080, zero }
  audit_$buffer_base: integer32;                   { +0x088, zero }
  audit_$buffer_size: integer32;                   { +0x08C, zero }
  audit_$write_ptr: integer32;                     { +0x090, zero }
  audit_$bytes_remaining: integer32;               { +0x094, zero }
  audit_$file_offset: integer32;                   { +0x098, zero }
  audit_$dirty: boolean;                           { +0x09C, zero }
  audit_$list_uid: uid_$t;                         { +0x0A0, zero }
  audit_$flags: audit_$flags_t;                    { +0x0A8, zero }
  audit_$timeout: integer;                         { +0x0AA, zero }
  audit_$list_count: integer;                      { +0x0AC, zero }
  audit_$hash_buckets: array[0..37] of audit_$hash_node_ptr_t;
                                                   { +0x0B0, zero }

define
  audit_$scsi_acquire_eu := [high := 16#0004001E, low := 0];
                                                   { +0x148 }
  audit_$acquire_ct_eu := [high := 16#00040011, low := 0];
                                                   { +0x150 }
  audit_$acquire_mt_eu := [high := 16#00040010, low := 0];
                                                   { +0x158 }
  audit_$acquire_lpr_eu := [high := 16#0004000F, low := 0];
                                                   { +0x160 }
  audit_$dismount_lv_eu := [high := 16#0004000E, low := 0];
                                                   { +0x168 }
  audit_$mount_lv_eu := [high := 16#0004000D, low := 0];
                                                   { +0x170 }
  audit_$assign_disk_eu := [high := 16#0004000C, low := 0];
                                                   { +0x178 }
  audit_$mount_disk_eu := [high := 16#0004000B, low := 0];
                                                   { +0x180 }
  audit_$enter_subs_eu := [high := 16#00040008, low := 0];
                                                   { +0x188 }
  audit_$set_sid_eu := [high := 16#00040007, low := 0];
                                                   { +0x190 }

var
  audit_$wired: audit_$wired_ptr_t;                { +0x198, zero }
  audit_$lock_id: integer32;                       { +0x19C, zero }
  audit_$server_pid: pinteger;                     { +0x1A0, zero }
  audit_$server_running: boolean;                  { +0x1A2, zero }
  audit_$pool_next: linteger;                      { +0x1A4, zero }
  audit_$pool_limit: linteger;                     { +0x1A8, zero }

{ The overlay section AUDIT_LIST (above). }
var (audit_list)
  audit_$list_pool: array[1..3072] of char;

define
  audit_$init;
  audit_$shutdown;
  audit_$is_process_audited;
  audit_$suspend;
  audit_$resume;
  audit_$log_event;
  audit_$log_event_s;
  audit_$server;
  audit_$administrator;
  audit_$control;
  audit_$inherit_audit;
  get_wired;

{ The module-local routines called before their bodies (internal, no
  map symbol). }

{ audit_$start_logging - load the audit list, open the log, start the
  server. }
{ body: audit/start_logging.pas }
procedure audit_$start_logging(out status: status_$t); forward; internal;

{ audit_$stop_logging: called by AUDIT_$SHUTDOWN and AUDIT_$CONTROL. }
{ body: audit/stop_logging.pas }
procedure audit_$stop_logging(out status: status_$t); forward; internal;

{ audit_$load_list - load the audit list into the hash table. }
{ body: audit/load_list.pas }
function audit_$load_list(out status: status_$t): boolean;
  forward; internal;

{ audit_$open_log - open, lock and map the audit log.
  audit_$close_log - write back, trim, unlock and forget the audit log. }
{ body: audit/open_log.pas }
procedure audit_$open_log(out status: status_$t); forward; internal;
{ body: audit/close_log.pas }
procedure audit_$close_log(out status: status_$t); forward; internal;

{ ---- WIRED_PROC ---- }
%include 'misc/get_wired.pas';              { GET_WIRED }

{ ---- .TEXT ---- }
%include 'audit/init.pas';                  { AUDIT_$INIT }
%include 'audit/start_logging.pas';         { audit_$start_logging }
%include 'audit/shutdown.pas';              { AUDIT_$SHUTDOWN }
%include 'audit/stop_logging.pas';          { audit_$stop_logging }
%include 'audit/is_process_audited.pas';    { AUDIT_$IS_PROCESS_AUDITED }
%include 'audit/suspend.pas';               { AUDIT_$SUSPEND }
%include 'audit/resume.pas';                { AUDIT_$RESUME }
%include 'audit/log_event.pas';             { AUDIT_$LOG_EVENT }
%include 'audit/log_event_s.pas';           { AUDIT_$LOG_EVENT_S }
%include 'audit/server.pas';                { AUDIT_$SERVER }
%include 'audit/alloc.pas';                 { audit_$alloc }
%include 'audit/load_list.pas';             { audit_$load_list, its nested
                                              audit_$clear_hash_table and
                                              audit_$add_to_hash }
%include 'audit/administrator.pas';         { AUDIT_$ADMINISTRATOR }
%include 'audit/control.pas';               { AUDIT_$CONTROL }
%include 'audit/inherit_audit.pas';         { AUDIT_$INHERIT_AUDIT }
%include 'audit/open_log.pas';              { audit_$open_log }
%include 'audit/close_log.pas';             { audit_$close_log }
