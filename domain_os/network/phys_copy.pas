{ network_$phys_copy - copy bytes between two physical addresses.

  Image addresses:
    sau2  0x00E0F120  network_$phys_copy (module-local)
    sau9  0x3C41157C  network_$phys_copy (module-local)

  - Under the PMAP lock the source page is mapped at the AST_$COPY_BUFF
    window and the destination page at the AST_$ZERO_BUFF window, the
    bytes copied (OS_$DATA_COPY) and both pages unmapped.
  - Neither window is checked for overrun.
  - With the large VM layout MMU_$REMOVE takes the virtual address.

  Status stored: none.
}

procedure network_$phys_copy(dst_pa: integer32; src_pa: integer32;
                             len: integer); internal;
var
  dst_va: network_$data_ptr_t;
  src_va: network_$data_ptr_t;
  dst_ppn: integer32;
  src_ppn: integer32;
begin
  { the two pages and the two windows }
  src_ppn := rshft(src_pa, 10);
  dst_ppn := rshft(dst_pa, 10);
  src_va := network_$data_ptr_t((src_pa & 16#3FF) +
                                integer32(addr(ast_$copy_buff)));
  dst_va := network_$data_ptr_t((dst_pa & 16#3FF) +
                                integer32(addr(ast_$zero_buff)));

  { map, copy, unmap, under the PMAP lock }
  ml_$lock(ml_$pmap_lock);
  mmu_$install(src_ppn, src_va, 0, 16#16);
  mmu_$install(dst_ppn, dst_va, 0, 16#16);
  os_$data_copy(src_va^, dst_va^, len);
%if large_vm %then
  mmu_$remove(src_va, 0);
  mmu_$remove(dst_va, 0);
%else
  mmu_$remove(src_ppn);
  mmu_$remove(dst_ppn);
%endif
  ml_$unlock(ml_$pmap_lock);
end;
