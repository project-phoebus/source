{ MST_$UNTHREAD_PMAP - invalidate every segment map entry on a page map's
  thread.

  Image addresses:
    sau4  0x0F80E844  MST_$UNTHREAD_PMAP
    sau6  0x7800E94A  MST_$UNTHREAD_PMAP
    sau7  0x3C40FD26  MST_$UNTHREAD_PMAP
    sau8  0x03C0F20E  MST_$UNTHREAD_PMAP
    sau9  0x3C4102E6  MST_$UNTHREAD_PMAP

  Assume we're called with the AST lock held.

  - Under the PMAP lock: each entry on the thread (an address space and
    a segment, through BST) has its segment map entry made invalid; the
    thread is then empty.

  Status stored: none.
}

procedure mst_$unthread_pmap(in out link: univ mst_$pmap_link_t);
var
  p: ^mst_$pmap_link_t;
  asid: integer;
  seg: pinteger;
begin
  ml_$lock(ml_$pmap_lock);
  p := addr(link);
  while p^.asid <> -1 do begin
    asid := p^.asid;
    seg := p^.seg;
    p := addr(bst[seg + bst_asid_base[asid]]);
%if region_mmu %then
    smaps[seg + smap_asid_base[asid]].e.valid := false;
%else
    smaps[seg + smap_asid_base[asid]].ctl.dt := mst_smap_invalid;
%endif
  end;
  link.asid := -1;
  ml_$unlock(ml_$pmap_lock);
end;
