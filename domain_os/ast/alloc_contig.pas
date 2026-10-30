{ AST_$ALLOC_CONTIG - allocate a run of contiguous physical pages.

  Image addresses:
    sau9  0x3C408424  AST_$ALLOC_CONTIG

  - MMAP_$ALLOC_CONTIG under the PMAP lock; a failure wakes the purifier
    and waits for it.

  Status stored:
    MMAP_$ALLOC_CONTIG's status: always
}

procedure ast_$alloc_contig(n: integer; out ppns: univ ast_$ppn_list_t;
                            out status: status_$t);
  options(val_param);
begin
  ml_$lock(ml_$pmap_lock);
  mmap_$alloc_contig(n, ppns, status);
  if status.all <> status_$ok then
    pmap_$wake_purifier(true);
  ml_$unlock(ml_$pmap_lock);
end;
