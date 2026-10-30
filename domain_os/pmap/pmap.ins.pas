{ pmap/pmap.ins.pas - PMAP_ (the paging daemon), for the Domain Pascal
  tree.

  Holds only what the Pascal files use: the PMAP_ variables
  OSINFO_$GET_MMAP reads and sets, the other map-named scalars of the
  block, the statuses, and the routines' headings.  No customer insert
  file declares these.  Include base/base.ins.pas and ml/ml.ins.pas
  before it (ml for MOUNT_LOCK).
}

var
  { Map symbols of the PMAP_ data block (pmap/pmap.pas lays it out),
    which OSINFO_$GET_MMAP reads and sets.  The three interval words are
    pinteger: PMAP_ compares them unsigned. }
  pmap_$idle_interval: extern integer32;
  pmap_$t_pur_scans: extern integer32;
  pmap_$pur_r_cnt: extern integer32;
  pmap_$pur_l_cnt: extern integer32;
  pmap_$scan_fract: extern integer;
  pmap_$min_ws_interval: extern pinteger;
  pmap_$max_ws_interval: extern pinteger;
  pmap_$ws_interval: extern pinteger;

  { MOUNT_LOCK (a map symbol without `$' in the PMAP_ block: a global):
    the volume table's exclusion lock, which DISK_ passes to
    ML_$EXCLUSION_START and _STOP. }
  mount_lock: extern ml_$exclusion_t;

{ PMAP_$PURGE_WS (pmap/purge_ws.pas): index is a process's number. }
procedure pmap_$purge_ws(index: integer; flag: boolean);
  options(extern, val_param);

{ PMAP_$INIT_WS_SCAN (pmap/init_ws_scan.pas): index is a process's
  number, ws_param its working-set list. }
procedure pmap_$init_ws_scan(index: pinteger; ws_param: integer);
  options(extern, val_param);

{ The PMAP manager's statuses PMAP_ uses, named from the SR10.2
  status-text tables (../stcodes, "OS / PMAP manager": 50003 mismatch,
  50006 bad assoc, 50007 pages wired, 50009 bad disk address, 50010
  illegal pid argument from dxm callback). }
const
  status_$pmap_mismatch = 16#00050003;
  status_$pmap_bad_assoc = 16#00050006;
  status_$pmap_pages_wired = 16#00050007;
  status_$pmap_bad_disk_address = 16#00050009;
  { 5000A "read concurrency violation", AST_$TOUCH's refusal. }
  status_$pmap_read_concurrency_violation = 16#0005000A;
  status_$pmap_illegal_pid_argument = 16#00050010;
  { 50004 "bad wire", 50005 "bad unwire" and 5000D "attempt to map i/o
    page over real page": the crashes of AST_$CACHE_INHIBIT_PPN,
    AST_$CACHE_ENABLE_PPN and AST_$ASSOC_IOPPN. }
  status_$pmap_bad_wire = 16#00050004;
  status_$pmap_bad_unwire = 16#00050005;
  status_$pmap_io_page_over_real_page = 16#0005000D;

{ The rest of the PMAP_ block's map-symbol scalars: the local
  purifier's page-count thresholds, the step it adds to
  PMAP_$WS_INTERVAL, and the shutdown flag.  The block's eventcounts and
  clocks are declared in pmap/pmap.pas, so that this file needs only
  base and ml. }
var
  pmap_$mid_thresh: extern pinteger;
  pmap_$low_thresh: extern pinteger;
  pmap_$ws_scan_delta: extern pinteger;
  pmap_$shutting_down_flag: extern boolean;

{ PMAP_$WAKE_PURIFIER - wake the purifiers, and wait for pages if asked. }
procedure pmap_$wake_purifier(wait: boolean); options(extern, val_param);

{ PMAP_$PURIFIER_L and PMAP_$PURIFIER_R: the two purifier processes'
  bodies (pmap/purifier_l.pas, purifier_r.pas). }
procedure pmap_$purifier_l; extern;
procedure pmap_$purifier_r; extern;

{ PMAP_$UPDATE_CALLBACK and PMAP_$T_PURIF_CALLBACK: the update and
  purifier timers' callbacks.  Neither reads the element pointer the
  time queue passes (time/time.ins.pas time_$callback_t), so neither
  declares it. }
procedure pmap_$update_callback; extern;
procedure pmap_$t_purif_callback; extern;

{ PMAP_$WS_SCAN_CALLBACK: the working-set scan timers' callback.  arg
  points to a record whose word at +2 is the process's number (the
  TODO(pascal) in pmap/ws_scan_callback.pas). }
type
  pmap_$ws_scan_arg_t = record
    unused_0: integer;                    { 0x00 }
    pid: pinteger;                        { 0x02 }
  end;
  pmap_$ws_scan_arg_ptr_t = ^pmap_$ws_scan_arg_t;

procedure pmap_$ws_scan_callback(in arg: pmap_$ws_scan_arg_ptr_t); extern;

const
  { "page null" (stcodes, stcode.db.10.2, 0x50008), the reply status
    NETWORK_$READ_AHEAD treats as pages not on disk. }
  status_$pmap_page_null = 16#00050008;
