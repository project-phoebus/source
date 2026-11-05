{ PROC1_$TST_LOCK - whether the current process holds a resource lock.

  Image addresses:
    sau2  0x00E148CA  PROC1_$TST_LOCK
    sau4  0x0F81513E  PROC1_$TST_LOCK
    sau6  0x7801507E  PROC1_$TST_LOCK
    sau7  0x3C4165D6  PROC1_$TST_LOCK

  Status stored: none.
}

function proc1_$tst_lock(lock_id: integer): boolean;
begin
  proc1_$tst_lock := lock_id in proc1_$current_pcb^.resource_locks_held;
end;
