{ osinfo/osinfo.ins.pas - OSINFO (the memory-management queries) types,
  constants and routine headings, for the Domain Pascal tree.

  The status codes, the records OSINFO_$GET_MMAP reads and fills, the
  buffer OSINFO_$GET_SEG_TABLE fills, and the two headings.  Apollo's
  customer osinfo.ins.pas (SR10.2) gives the two status codes' names.

  Include base/base.ins.pas and ast/ast.ins.pas before it.
}

const
  { Apollo's osinfo.ins.pas, its names and values: "user array too
    small" (stcode.db.10.2: "array too small for complete table") and
    "incorrect version number".  OSINFO_$GET_SEG_TABLE stores the first;
    OSINFO_$GET_MMAP the second for an ASID out of range. }
  osinfo_$array_toosmall = 16#00200001;
  osinfo_$wrong_version  = 16#00200002;

  { Neither Apollo's insert nor stcode.db.10.2 has these codes.
    OSINFO_$GET_MMAP stores them for a page found and a wired one. }
  status_$os_info_page_found = 16#00200003;
  status_$os_info_page_wired = 16#00200004;

  { The number of ASTEs, the bound of the tables (ast/ast.ins.pas). }
  osinfo_$max_astes = 504;

type
  { The request flags of OSINFO_$GET_MMAP, a set.  The body tests them
    in the second byte of the word its first argument points to: members
    0..6 of a one-word set (ref 3.9.3; the byte form of a member
    test). }
  osinfo_$mmap_flag_t = (osinfo_$get_counters,   { 0 }
                         osinfo_$get_global,     { 1 }
                         osinfo_$get_ws_info,    { 2 }
                         osinfo_$get_ws_list,    { 3 }
                         osinfo_$get_pid,        { 4 }
                         osinfo_$set_params,     { 5 }
                         osinfo_$find_page);     { 6 }
  osinfo_$mmap_flags_t = set of osinfo_$mmap_flag_t;

  { The paging counters, 0x42 bytes: OSINFO_$GET_MMAP stores fifteen
    longwords and a word through the slot; +0x28 is not written. }
  osinfo_$paging_counters_t = record
    pur_l_cnt: integer32;                 { 0x00 }
    pur_r_cnt: integer32;                 { 0x04 }
    page_flt_cnt: integer32;              { 0x08 }
    ws_flt_cnt: integer32;                { 0x0C }
    t_pur_scans: integer32;               { 0x10 }
    alloc_cnt: integer32;                 { 0x14 }
    alloc_pages: integer32;               { 0x18 }
    steal_cnt: integer32;                 { 0x1C }
    ws_overflow: integer32;               { 0x20 }
    ws_scan_cnt: integer32;               { 0x24 }
    reserved_28: integer32;               { 0x28 }
    ast_alloc_cnt: integer32;             { 0x2C }
    alloc_too_few: integer32;             { 0x30 }
    reclaim_shar_cnt: integer32;          { 0x34 }
    reclaim_pur_cnt: integer32;           { 0x38 }
    ws_remove: integer32;                 { 0x3C }
    scan_fract: integer;                  { 0x40 }
  end;

  { The request and global information record, 0x32 bytes.  The longword
    at 0x28 is read and written whole and its low word alone (the set
    operation 0's interval): a variant part from 0x28 (ref 3.10.3).
    set_value is integer32 (-1 is stored); set_op is the jump table's
    selector: integer; asid and ws_list_count are compared unsigned:
    pinteger.  ws_data are five longwords, the pools' page counts. }
  osinfo_$global_info_t = record
    real_pages: integer32;                { 0x00 }
    pageable_lower_limit: integer32;      { 0x04 }
    remote_pages: integer32;              { 0x08 }
    ws_data: array[0..4] of integer32;    { 0x0C..0x1F }
    ws_interval: integer;                 { 0x20 }
    wsl_hi_mark: pinteger;                { 0x22 }
    pid: integer;                         { 0x24 }
    set_op: integer;                      { 0x26 }
    case integer of
      1: (set_value: integer32;           { 0x28 }
          reserved_2c: integer;           { 0x2C }
          asid: pinteger;                 { 0x2E }
          ws_list_count: pinteger);       { 0x30 }
      2: (set_value_hi: integer;          { 0x28 }
          set_value_lo: integer);         { 0x2A }
  end;

  { One entry of the working set information, 12 bytes: OSINFO_$GET_MMAP
    stores three longwords and steps by 0xC.  The names are the
    MMAP_$WSL fields'. }
  osinfo_$ws_info_t = record
    page_count: integer32;                { 0x00 }
    pri_timestamp: integer32;             { 0x04 }
    ws_timestamp: integer32;              { 0x08 }
  end;
  osinfo_$ws_info_list_t = array[1..65] of osinfo_$ws_info_t;

  { One entry of the working set list, 4 bytes: two words stepped by 4,
    MMAP_$WS_OWNER's word and PROC1_$TYPE's. }
  osinfo_$ws_list_entry_t = record
    owner: pinteger;                      { 0x00 }
    proc_type: integer;                   { 0x02 }
  end;
  osinfo_$ws_list_t = array[1..64] of osinfo_$ws_list_entry_t;

  { OSINFO_$GET_SEG_TABLE's buffer: entries of the AST (0x14 bytes) or of
    AST_PMAPS (0x80 bytes), copied to the caller's buffer from its first
    byte with the same stepping as the source's: two variants of one
    array each (ref 3.10.3). }
  osinfo_$seg_buf_t = record
    case integer of
      1: (aste: array[1..osinfo_$max_astes] of ast_$aste_t);
      2: (pmap: array[1..osinfo_$max_astes] of ast_$pmap_t);
  end;

{ Routine headings, in map order (the map's OSINFO code segment, .TEXT).
  Both are reached through the SVC table only (no call names them): user
  entry points, the default convention, every argument by address.  The
  bodies repeat the full heading (ref 7.3.4, Method 2). }

{ OSINFO_$GET_SEG_TABLE - copy the active segment table or its page maps to
  the caller. }
procedure osinfo_$get_seg_table(in table_type: integer;
                                out buffer: univ osinfo_$seg_buf_t;
                                in max_entries: integer;
                                out actual_entries: integer;
                                out total_entries: integer;
                                out status: status_$t);
  extern;

{ OSINFO_$GET_MMAP - query and tune the memory-management subsystem. }
procedure osinfo_$get_mmap(in flags: osinfo_$mmap_flags_t;
                           out counters: osinfo_$paging_counters_t;
                           in out info: osinfo_$global_info_t;
                           out ws_data: univ osinfo_$ws_info_list_t;
                           out ws_list: univ osinfo_$ws_list_t;
                           var uid_out: uid_$t;
                           out status: status_$t);
  extern;

{ ---- OSINFO's dispatch codes, named. ----

  OSINFO_$GET_MMAP's set operation (the info record's set_op word at
  +0x26, its `case info.set_op of' when osinfo_$set_params is in the
  flags, a jump table of five entries).  Apollo's osinfo.ins.pas does
  not declare them. }
const
  osinfo_$set_ws_interval = 0;
  osinfo_$set_idle_interval = 1;
  osinfo_$set_ws_max = 2;
  osinfo_$purge_ws = 3;
  osinfo_$set_ws_limit = 4;
{ ---- end of OSINFO's dispatch codes ---- }
