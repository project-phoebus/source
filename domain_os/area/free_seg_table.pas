{ area_$free_seg_table - return an overflow segment table to the pool.

  Image addresses:
    sau2  0x00E09E48  area_$free_seg_table (module-local)
    sau4  0x0F80A676  area_$free_seg_table (module-local)
    sau9  0x3C40B906  area_$free_seg_table (module-local)

  - Under the AST lock the table's page is unmapped and freed when it is
    mapped, the table counted out and unlinked from its address space's
    list, and the pool's search cursor lowered to it.
  - With the large VM layout MMU_$REMOVE takes the virtual address.

  Status stored: none.
}

procedure area_$free_seg_table(tbl: area_$seg_table_ptr_t;
                               prev: area_$seg_table_ptr_t; asid: integer);
  internal;
var
  st: status_$t;
  ppn: integer32;
  idx: integer;
begin
  ml_$lock(ml_$ast_lock);

  { the pool index from the page's address }
  idx := rshft(integer32(tbl^.bitmap) - integer32(addr(pit_pages)), 10);

  { unmap and free the page }
  ppn := mmu_$vtop(integer32(tbl^.bitmap), st);
  if st.all = status_$ok then begin
%if large_vm %then
    mmu_$remove(tbl^.bitmap, 0);
%else
    mmu_$remove(ppn);
%endif
    mmap_$free(ppn);
  end;

  { count it out, unlink it }
  area_$format.seg_table_count := area_$format.seg_table_count - 1;
  if prev = nil then
    area_$seg_table_list[asid] := tbl^.next
  else
    prev^.next := tbl^.next;
  tbl^.next := nil;
  tbl^.allocated := false;

  { the search cursor }
  if idx > area_$format.seg_table_next then
    idx := area_$format.seg_table_next;
  area_$format.seg_table_next := idx;

  ml_$unlock(ml_$ast_lock);
end;
