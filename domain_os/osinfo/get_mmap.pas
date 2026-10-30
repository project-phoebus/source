{ OSINFO_$GET_MMAP - query and tune the memory-management subsystem.

  Image addresses:
    sau2  0x00E5C694  OSINFO_$GET_MMAP
    sau9  0x3C4636E0  OSINFO_$GET_MMAP

  - Each request flag runs one block, in order: set_params, find_page,
    get_pid, get_global, get_counters, get_ws_list (up to 64), and
    get_ws_info.
  - set_params: five working set operations, for the ASID in info or the
    current process's.
  - find_page finds the next page of an ASID's working set (1..69), an
    unwired page's object UID handed back; a start above MMAP_$HPPN
    gives -1.  Both a bad ASID and such a start leave the routine.

  Status stored:
    status_$ok: the requests ran
    osinfo_$wrong_version: find_page for an ASID outside 1..69
    status_$os_info_page_wired: find_page found a wired page
    status_$os_info_page_found: find_page found an unwired page
    mmap_$set_ws_max's or proc2_$get_pid's status: that request's
}

{ TODO(pascal) 12 frame bytes unexplained (stand-in unused_18)

  The SAU2 frame holds 12 bytes more than the five locals above (with
  wsl_index where the image addresses it); the stand-in unused_18 holds
  them (the KBD and TPAD convention).  Pointer locals for the info
  record, the counters, the two lists and the page entry would account
  for more than 12 bytes; which of them, if any, the original declared
  is not known. }

procedure osinfo_$get_mmap(in flags: osinfo_$mmap_flags_t;
                           out counters: osinfo_$paging_counters_t;
                           in out info: osinfo_$global_info_t;
                           out ws_data: univ osinfo_$ws_info_list_t;
                           out ws_list: univ osinfo_$ws_list_t;
                           var uid_out: uid_$t;
                           out status: status_$t);
var
  ppn: linteger;
  asid: pinteger;
  wsl_index: pinteger;
  count: pinteger;
  k: integer;
  unused_18: array[1..3] of integer32;    { the stand-in (TODO) }
begin
  status.all := status_$ok;

  { the set operations }
  if osinfo_$set_params in flags then
    case info.set_op of
      osinfo_$set_ws_interval: begin
        pmap_$ws_interval := info.set_value_lo;
        pmap_$max_ws_interval := info.set_value_lo;
        pmap_$min_ws_interval := info.asid;
      end;
      osinfo_$set_idle_interval: begin
        pmap_$idle_interval := info.set_value;
      end;
      osinfo_$set_ws_max: begin
        asid := info.asid;
        if (asid = 0) or else (asid > 64) then
          asid := proc1_$current;
        wsl_index := mmap_$ws_owner[asid];
        mmap_$set_ws_max(wsl_index, info.set_value, status);
      end;
      osinfo_$set_ws_limit: begin
        asid := info.asid;
        if (asid = 0) or else (asid > 64) then
          asid := proc1_$current;
        mmap_$wsl[mmap_$ws_owner[asid]].ws_floor := info.set_value;
      end;
      osinfo_$purge_ws: begin
        asid := info.asid;
        if (asid = 0) or else (asid > 64) then
          asid := proc1_$current;
        pmap_$purge_ws(asid, true);
      end;
    end;

  { the next page of an address space }
  if osinfo_$find_page in flags then begin
    asid := info.asid;
    if (asid = 0) or else (asid > 69) then begin
      status.all := osinfo_$wrong_version;
      return;
    end;
    ppn := info.set_value;
    if ppn < mmap_$lppn then
      ppn := mmap_$lppn;
    if ppn > mmap_$hppn then begin
      info.set_value := -1;
      return;
    end;
    while ppn <= mmap_$hppn do begin
      if mmap[ppn].in_wsl and then (mmap[ppn].wsl_index = asid) then begin
        if mmap[ppn].flags2_7 then
          status.all := status_$os_info_page_wired
        else begin
          status.all := status_$os_info_page_found;
          uid_out := ast[mmap[ppn].segment].aote^.uid;
        end;
        ppn := ppn + 1;
        exit;
      end;
      ppn := ppn + 1;
    end;
    info.set_value := ppn;
  end;

  if osinfo_$get_pid in flags then
    info.pid := proc2_$get_pid(uid_out, status);

  if osinfo_$get_global in flags then begin
    info.real_pages := mmap_$real_pages;
    info.pageable_lower_limit := mmap_$pageable_pages;
    info.remote_pages := mmap_$remote_pages;
    info.wsl_hi_mark := mmap_$wsl_hi_mark;
    info.ws_data[0] := mmap_$wsl[0].page_count;
    info.ws_data[1] := mmap_$wsl[1].page_count;
    info.ws_data[2] := mmap_$wsl[2].page_count;
    info.ws_data[3] := mmap_$wsl[3].page_count;
    info.ws_data[4] := mmap_$wsl[4].page_count;
    info.ws_interval := pmap_$ws_interval;
  end;

  if osinfo_$get_counters in flags then begin
    counters.pur_l_cnt := pmap_$pur_l_cnt;
    counters.pur_r_cnt := pmap_$pur_r_cnt;
    counters.page_flt_cnt := ast_$page_flt_cnt;
    counters.ws_flt_cnt := ast_$ws_flt_cnt;
    counters.t_pur_scans := pmap_$t_pur_scans;
    counters.alloc_cnt := mmap_$alloc_cnt;
    counters.alloc_pages := mmap_$alloc_pages;
    counters.steal_cnt := mmap_$steal_cnt;
    counters.ws_overflow := mmap_$ws_overflow;
    counters.ws_scan_cnt := mmap_$ws_scan_cnt;
    counters.ast_alloc_cnt := ast_$alloc_cnt;
    counters.alloc_too_few := ast_$alloc_too_few_cnt;
    counters.reclaim_shar_cnt := mmap_$reclaim_shar_cnt;
    counters.reclaim_pur_cnt := mmap_$reclaim_pur_cnt;
    counters.ws_remove := mmap_$ws_remove;
    counters.scan_fract := pmap_$scan_fract;
  end;

  if osinfo_$get_ws_list in flags then begin
    count := 64;
    if count >= info.ws_list_count then
      count := info.ws_list_count;
    info.ws_list_count := count;
    for k := 1 to count do begin
      ws_list[k].owner := mmap_$ws_owner[k];
      ws_list[k].proc_type := proc1_$type[k];
    end;
  end;

  if osinfo_$get_ws_info in flags then
    for k := 5 to mmap_$wsl_hi_mark do begin
      ws_data[k - 4].page_count := mmap_$wsl[k].page_count;
      ws_data[k - 4].pri_timestamp := mmap_$wsl[k].pri_timestamp;
      ws_data[k - 4].ws_timestamp := mmap_$wsl[k].ws_timestamp;
    end;
end;
