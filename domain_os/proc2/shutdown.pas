{ PROC2_$SHUTDOWN - suspend every other bound process.

  Image addresses:
    sau2  0x00E415C2  PROC2_$SHUTDOWN

  - PROC2_$SUSPEND for each bound entry of another address space, its
    status never read.  No lock is taken.

  Status stored: none.
}

procedure proc2_$shutdown;
var
  unused_28: array[1..40] of char;        { nothing reaches
                                            it; the TODO(pascal) below }
  status: status_$t;
  index: integer;
begin
  index := p2_info_alloc_ptr;
  if index <> 0 then
    repeat
      with proc2_$info_table[index] do begin
        if (asid <> proc1_$as_id)
           and then (proc2_pf_bound in flags.bits) then
          proc2_$suspend(uid, status);
        index := next_index;
      end;
    until index = 0;
end;

{ TODO(pascal) PROC2_$SHUTDOWN's frame has 40 bytes nothing addresses
  above its status: more than the homes of the two register-held locals.
  The original's extra locals are not known; the stand-in unused_28
  keeps status at its place. }
