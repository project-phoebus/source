{ AST_$ADD_ASTES - grow the ASTE pool.

  Image addresses:
    sau2  0x00E0118C  AST_$ADD_ASTES
    sau4  0x0F80158C  AST_$ADD_ASTES
    sau6  0x78001960  AST_$ADD_ASTES
    sau7  0x3C401D6C  AST_$ADD_ASTES
    sau8  0x03C0156C  AST_$ADD_ASTES
    sau9  0x3C40256C  AST_$ADD_ASTES

  - As AST_$ADD_AOTES, for ASTEs, with sizes 80..ast_$max_astes.  Each
    segment's page-map row in AST_PMAPS (128 bytes) is mapped and
    cleared too.
  - The new ASTEs get their segment index, are counted as local and go
    to AST_$FREE_ASTE; the result is the pool's size.

  Status stored:
    status_$ok: the pool grew
    status_$ast_incompatible_request: the new size is out of range
}

function ast_$add_astes(in count: integer; out status_ret: status_$t):
  integer;
var
  status: status_$t;
  ppn: integer32;
  va: integer32;
  add_count: integer;
  new_size: integer32;
  aste: ast_$aste_ptr_t;
  row_va: integer32;
  i: integer;
  j: integer;
begin
  add_count := count;
  status.all := status_$ok;
  new_size := pinteger(ast_$size_ast) + add_count;

  if (new_size <= ast_$max_astes) and then (new_size >= 80) then begin
    { the page at the limit mapped }
    va := integer32(ast_$aste_limit);
    discard(mmu_$vtop(va, status));
    if status.all <> status_$ok then begin
      wp_$calloc(ppn, status);
      if status.all <> status_$ok then
        crash_system(status);
      mmu_$install(ppn, univ_ptr(va), 0, 16#16);
    end;

    ml_$lock(ml_$ast_lock);

    { each new ASTE and its page-map row }
    for i := ast_$size_ast + 1 to ast_$size_ast + add_count do begin
      aste := ast_$aste_limit;
      ast_$aste_limit := ast_$aste_ptr_t(integer32(ast_$aste_limit) +
                                         sizeof(ast_$aste_t));
      va := integer32(ast_$aste_limit) - 1;
      ml_$unlock(ml_$ast_lock);

      discard(mmu_$vtop(va, status));
      if status.all <> status_$ok then begin
        wp_$calloc(ppn, status);
        if status.all <> status_$ok then
          crash_system(status);
        mmu_$install(ppn, univ_ptr(va), 0, 16#16);
      end;

      for j := 1 to sizeof(ast_$aste_t) div 2 do
        ast_$words_ptr_t(aste)^[j] := 0;

      row_va := integer32(addr(ast_pmaps[i]));
%if large_vm %then
      ppn := mmu_$vtop(row_va, status);
%else
      discard(mmu_$vtop(row_va, status));
%endif
      if status.all <> status_$ok then begin
        wp_$calloc(ppn, status);
        if status.all <> status_$ok then
          crash_system(status);
        mmu_$install(ppn, univ_ptr(row_va), 0, 16#16);
%if pmap_cache_inhibit %then
        mmu_$cache_inhibit_va(univ_ptr(row_va));
%endif
      end;
%if large_vm %then
      { the page map's physical address, for the MMU's tables }
      aste^.pmap_pa := ppn * 1024 + (row_va & 16#3FF);
%endif

      for j := 1 to 64 do
        ast_$words_ptr_t(row_va)^[j] := 0;

      aste^.seg_index := i;
      ml_$lock(ml_$ast_lock);
      ast_$aste_l_cnt := ast_$aste_l_cnt + 1;
      ast_$free_aste(aste^);
    end;

    ast_$size_ast := ast_$size_ast + add_count;
    ml_$unlock(ml_$ast_lock);
  end
  else
    status.all := status_$ast_incompatible_request;

  status_ret := status;
  ast_$add_astes := ast_$size_ast;
end;
