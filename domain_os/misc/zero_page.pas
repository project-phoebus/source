{ zero_page - clear one physical page through the zero window.

  Image addresses:
    sau2  0x00E00EB0  zero_page (module-local)
    sau9  0x3C402290  zero_page (module-local)

  - The page is mapped at AST_$ZERO_BUFF (address space 0, protection
    16#16), its 1024 bytes cleared as 256 longwords, and unmapped.  A
    fragment of the AST_ module.
  - With the large VM layout MMU_$REMOVE takes the virtual address.

  Status stored: none.
}

procedure zero_page(ppn: integer32); internal;
var
  i: integer;
  unused_c: integer32;                    { stand-in }
begin
  mmu_$install(ppn, addr(ast_$zero_buff), 0, 16#16);

  for i := 0 to 255 do
    ast_$zero_buff[i] := 0;

%if large_vm %then
  mmu_$remove(addr(ast_$zero_buff), 0);
%else
  mmu_$remove(ppn);
%endif
end;
