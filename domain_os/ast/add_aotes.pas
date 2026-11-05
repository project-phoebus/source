{ AST_$ADD_AOTES - grow the AOTE pool.

  Image addresses:
    sau2  0x00E01014  AST_$ADD_AOTES
    sau4  0x0F801416  AST_$ADD_AOTES
    sau6  0x780017EA  AST_$ADD_AOTES
    sau7  0x3C401BF6  AST_$ADD_AOTES
    sau8  0x03C013F6  AST_$ADD_AOTES
    sau9  0x3C4023F6  AST_$ADD_AOTES

  - A new pool size (AST_$SIZE_AOT plus count) outside 40..ast_$max_aotes is
    refused.  Otherwise each new AOTE (192 bytes) is carved off the
    pool's limit under the AST lock, its page mapped when it has none.
  - The new AOTEs are cleared and released; the result is the pool's
    size.

  Status stored:
    status_$ok: the pool grew
    status_$ast_incompatible_request: the new size is out of range
}

function ast_$add_aotes(in count: integer; out status_ret: status_$t):
  integer;
var
  status: status_$t;
  ppn: integer32;
  va: integer32;
  add_count: integer;
  new_size: integer32;
  aote: ast_$aote_ptr_t;
  i: integer;
  j: integer;
begin
  add_count := count;
  status.all := status_$ok;
  new_size := pinteger(ast_$size_aot) + add_count;

  if (new_size <= ast_$max_aotes) and then (new_size >= 40) then begin
    { the page at the limit mapped }
    va := integer32(ast_$aote_limit);
    discard(mmu_$vtop(va, status));
    if status.all <> status_$ok then begin
      wp_$calloc(ppn, status);
      if status.all <> status_$ok then
        crash_system(status);
      mmu_$install(ppn, univ_ptr(va), 0, 16#16);
    end;

    ml_$lock(ml_$ast_lock);

    { each new AOTE }
    for i := ast_$size_aot + 1 to ast_$size_aot + add_count do begin
      aote := ast_$aote_limit;
      ast_$aote_limit := ast_$aote_ptr_t(integer32(ast_$aote_limit) +
                                         192);
      va := integer32(ast_$aote_limit) - 1;
      ml_$unlock(ml_$ast_lock);

      discard(mmu_$vtop(va, status));
      if status.all <> status_$ok then begin
        wp_$calloc(ppn, status);
        if status.all <> status_$ok then
          crash_system(status);
        mmu_$install(ppn, univ_ptr(va), 0, 16#16);
      end;

      for j := 1 to 96 do
        ast_$words_ptr_t(aote)^[j] := 0;

      ml_$lock(ml_$ast_lock);
      ast_$release_aote(aote^);
    end;

    ast_$size_aot := ast_$size_aot + add_count;
    ml_$unlock(ml_$ast_lock);
  end
  else
    status.all := status_$ast_incompatible_request;

  status_ret := status;
  ast_$add_aotes := ast_$size_aot;
end;
