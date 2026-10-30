{ ast_$read_area_pages_network - read a run of a remote segment's pages
  from the object's home node.

  Image addresses:
    sau2  0x00E02CA6  ast_$read_area_pages_network (module-local)
    sau9  0x3C404000  ast_$read_area_pages_network (module-local)
    sau2  0x00E02C52  ast_$read_area_pages_net_log (nested)
    sau9  0x3C403FAC  ast_$read_area_pages_net_log (nested)

  Assume we're called with the PMAP lock held.

  - count frames are allocated and, with the lock released, the run read
    from the home node (NETWORK_$READ_AHEAD); read-ahead is suppressed
    when the AOTE was touched.
  - Null pages are zeroed.  The object's clocks come from the reply, and
    its length is extended to cover the run.  The result is the pages
    read.
  - ast_$read_area_pages_net_log, nested, writes the NETLOG record.

  Status stored:
    status_$ok: pages arrived
    network_$read_ahead's status: nothing arrived
}

function ast_$read_area_pages_network(var aste: ast_$aste_t;
                                      var segmap: univ ast_$pmap_run_t;
                                      out ppn_array: univ ast_$ppn_list_t;
                                      start_page: pinteger;
                                      count: pinteger; flags: boolean;
                                      out status_ret: status_$t): integer;
  internal;
var
  request: network_$page_request_t;
  acl_info: time_$clock_t;
  dtm: time_$clock_t;
  clock: time_$clock_t;
  buf: integer32;
  n_pages: integer;
  page_size: pinteger;
  no_read_ahead: boolean;
  aote: ast_$aote_ptr_t;
  allocated: pinteger;
  pages_read: integer;
  null_pages: boolean;
  i: integer;

  procedure ast_$read_area_pages_net_log(count: integer;
                                         null_pages: boolean);
  var
    kind: integer;
  begin
    if null_pages then
      kind := 8
    else
      kind := 9;

    netlog_$log_it(kind, aste.aote^.uid, aste.segment, start_page, 0, 0,
                   count, 0);
  end;

begin
  aote := aste.aote;
  allocated := ast_$allocate_pages(count, 1, ppn_array);
  no_read_ahead := 4 in aote^.flags;
  aote^.flags := aote^.flags - [4];

  ml_$unlock(ml_$pmap_lock);
  for i := 1 to allocated do
    netbuf_$rtn_dat(ppn_array[i] * 1024);

  { the request }
  request.uid := aote^.uid;
  request.page_num := aste.segment * 32 + start_page;
  n_pages := allocated;
  page_size := lshft(1, (aote^.unknown_9d & 16#F) + 9);

  pages_read := network_$read_ahead(aote^.obj_loc_addr, request, ppn_array,
                                    page_size, n_pages, no_read_ahead,
                                    flags, dtm, clock, acl_info,
                                    status_ret);

  { the frames not filled }
  for i := pages_read + 1 to allocated do begin
    netbuf_$get_dat(buf);
    mmap_$free(rshft(buf, 10));
  end;

  if pages_read > 0 then begin
    status_ret.all := status_$ok;
    null_pages := ppn_array[1] = 0;
    if null_pages then
      for i := 1 to pages_read do begin
        netbuf_$get_dat(buf);
        ppn_array[i] := rshft(buf, 10);
      end;

    ml_$lock(ml_$pmap_lock);
    for i := 1 to pages_read do
      with segmap[i] do begin
        if null_pages then begin
          zero_page(ppn_array[i]);
%if pmmu_page_maps %then
          hi_flags := hi_flags + [15];
%else
          flags := flags + [6];
%endif
        end;
        dentry.daddr := 1;
      end;

    { the clocks }
    if dtm.high = 0 then
      time_$clock(clock)
    else begin
      aote^.dtu := dtm;
      aote^.dtm := acl_info;
      aote^.dta := clock;
    end;

    { the length }
    if (start_page + pages_read - 1 + aste.segment * 32) * 1024 >=
       integer32(aote^.length) then begin
      aote^.length := (start_page + pages_read - 1 + aste.segment * 32) *
                      1024 + 1024;
      if dtm.high = 0 then begin
        aote^.dta := clock;
        aote^.dtm := clock;
      end;
    end
    else if dtm.high = 0 then
      aote^.dtu := clock;

    if netlog_$ok_to_log then
      ast_$read_area_pages_net_log(pages_read, null_pages);
  end
  else
    ml_$lock(ml_$pmap_lock);

  proc1_$stats[proc1_$current].stat[4] :=
    proc1_$stats[proc1_$current].stat[4] + pages_read;
  ast_$read_area_pages_network := pages_read;
end;
