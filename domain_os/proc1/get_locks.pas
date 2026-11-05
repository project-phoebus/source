{ PROC1_$GET_LOCKS - the current process's lock set as a longword.

  Image addresses:
    sau2  0x00E148E6  PROC1_$GET_LOCKS
    sau4  0x0F81515A  PROC1_$GET_LOCKS
    sau6  0x7801509A  PROC1_$GET_LOCKS
    sau7  0x3C4165F2  PROC1_$GET_LOCKS

  Status stored: none.
}

function proc1_$get_locks: integer32;
begin
  proc1_$get_locks := proc1_$current_pcb^.resource_locks_word;
end;
