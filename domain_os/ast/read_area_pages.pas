{ ast_$read_area_pages - read a run of a local segment's pages from disk.

  Image addresses:
    sau2  0x00E02AF6  ast_$read_area_pages (module-local)
    sau9  0x3C403E56  ast_$read_area_pages (module-local)

  Assume we're called with the PMAP lock held.

  - count frames are allocated (at least one) and, with the lock
    released, read in one DISK_$READ_MULTI from the run's map entries.
  - The frames that were not filled are freed; the result is the pages
    read, also added to the calling process's third statistic.

  Status stored:
    disk_$read_multi's status: the read, with the fail bit on a failure
}

function ast_$read_area_pages(var aste: ast_$aste_t;
                              var segmap: univ ast_$pmap_run_t;
                              out ppn_array: univ ast_$ppn_list_t;
                              start_page: pinteger; count: pinteger;
                              out status_ret: status_$t): integer;
  internal;
var
  qblk_tail: disk_$io_req_ptr_t;
  qblk_head: disk_$io_req_ptr_t;
  vol_idx: pinteger;
  pages_read: integer;
  allocated: pinteger;
  req: disk_$io_req_ptr_t;
  i: integer;
begin
  allocated := ast_$allocate_pages(count, 1, ppn_array);
  ml_$unlock(ml_$pmap_lock);

  vol_idx := aste.aote^.vol_index;
  disk_$get_qblks(allocated, qblk_head, qblk_tail);

  { the head block's header }
  req := qblk_head;
  req^.header.hint := start_page + aste.segment * 32;
  req^.header.uid := aste.aote^.uid;
  req^.header.byte_10 := chr(0);

  for i := 1 to allocated do begin
    req^.ppn := ppn_array[i];
    req^.daddr.daddr := segmap[i].dentry.daddr;
    req := req^.free_next;
  end;

  disk_$read_multi(vol_idx, true, true, qblk_head, qblk_tail, pages_read,
                   status_ret);
  if status_ret.all <> status_$ok then
    status_ret.fail := true;

  ml_$lock(ml_$pmap_lock);
  disk_$rtn_qblks(allocated, qblk_head, qblk_tail);

  if allocated <> pages_read then
    for i := pages_read + 1 to allocated do
      mmap_$free(ppn_array[i]);

  proc1_$stats[proc1_$current].stat[3] :=
    proc1_$stats[proc1_$current].stat[3] + pages_read;
  ast_$read_area_pages := pages_read;
end;
