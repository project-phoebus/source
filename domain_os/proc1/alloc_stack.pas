{ PROC1_$ALLOC_STACK - allocate and map a process stack.

  Image addresses:
    sau2  0x00E1501A  PROC1_$ALLOC_STACK
    sau4  0x0F81588E  PROC1_$ALLOC_STACK

  - Under the PROC1 create lock.  The size is rounded up to whole 1 KB
    pages; the result is the stack's top.
  - A stack under 4 KB grows the low region upward, a 4 KB stack is
    taken from the free list when it has one, any other grows the high
    region downward; the two regions may not cross.
  - When the high region has no room the result is not written.

  Status stored:
    status_$ok: the stack was allocated
    status_$no_stack_space_is_available: no room, or a page could not be
      allocated
}

function proc1_$alloc_stack(size: pinteger; out status_ret: status_$t): linteger;
label
  10, 20, 30;
var
  stack: linteger;
  page: integer32;
  top: linteger;
  small: boolean;
begin
  status_ret.all := status_$ok;
  ml_$lock(ml_$proc1_create_lock);
  size := (size + 16#3FF) & 16#FC00;
  small := size < 4096;

  { the low region }
  if small then begin
    top := size + proc1_$stack_low_water + 1024;
    stack := top;
    if top <= proc1_$stack_high_water then
      goto 30;
    goto 10;
  end;

  { a free 4 KB stack }
  if (proc1_$stack_free_list <> 0) and then (size = 4096) then begin
    top := proc1_$stack_free_list + 4;
    stack := top;
    proc1_$stack_free_list := proc1_$stack_link_ptr_t(proc1_$stack_free_list)^;
    goto 20;
  end;

  { the high region }
  top := proc1_$stack_high_water - size - 1024;
  if top < proc1_$stack_low_water then
    goto 10;
  stack := proc1_$stack_high_water;

  { the pages }
30:
  if size <> 0 then
    repeat
      wp_$calloc(page, status_ret);
      if status_ret.all <> status_$ok then
        goto 10;
      mmu_$install(page, univ_ptr(stack - size), 0, 16#16);
      size := size - 1024;
    until size = 0;

  if small then
    proc1_$stack_low_water := stack
  else
    proc1_$stack_high_water := top;
  goto 20;

10:
  status_ret.all := status_$no_stack_space_is_available;

20:
  ml_$unlock(ml_$proc1_create_lock);
  proc1_$alloc_stack := stack;
end;
