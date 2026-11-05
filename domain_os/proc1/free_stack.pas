{ PROC1_$FREE_STACK - put a stack on the free list.

  Image addresses:
    sau2  0x00E1511A  PROC1_$FREE_STACK
    sau4  0x0F81598E  PROC1_$FREE_STACK
    sau6  0x78015896  PROC1_$FREE_STACK
    sau7  0x3C416DEE  PROC1_$FREE_STACK

  - Only a stack above the high-water mark (a 4 KB stack of the high
    region), compared unsigned, is linked in, through the longword below
    its top; any other is dropped.

  Status stored: none.
}

procedure proc1_$free_stack(stack: linteger);
var
  link: linteger;
begin
  if stack > proc1_$stack_high_water then begin
    link := stack - 4;
    proc1_$stack_link_ptr_t(link)^ := proc1_$stack_free_list;
    proc1_$stack_free_list := link;
  end;
end;
