{ AST_$PAGE_ZERO - zero a physical page under the PMAP lock.

  Image addresses:
    sau2  0x00E00EEC  AST_$PAGE_ZERO
    sau4  0x0F8012F6  AST_$PAGE_ZERO
    sau6  0x780016CE  AST_$PAGE_ZERO
    sau7  0x3C401AD2  AST_$PAGE_ZERO
    sau9  0x3C4022D2  AST_$PAGE_ZERO

  - The page is cleared through zero_page (misc/zero_page.pas: mapped at
    AST_$ZERO_BUFF, 256 longwords cleared, unmapped).

  Status stored: none.
}

procedure ast_$page_zero(ppn: integer32); options(val_param);
begin
  ml_$lock(ml_$pmap_lock);

  zero_page(ppn);

  ml_$unlock(ml_$pmap_lock);
end;
