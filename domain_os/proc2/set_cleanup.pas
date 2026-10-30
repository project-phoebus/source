{ PROC2_$SET_CLEANUP - flag a cleanup handler for the calling process.

  Image addresses:
    sau2  0x00E41572  PROC2_$SET_CLEANUP

  - For a caller with an address space, the handler's member is added to
    its entry's cleanup set, which proc2_$cleanup_handlers_internal walks
    at exit.  No lock.

  Status stored: none.
}

procedure proc2_$set_cleanup(handler_bit: integer);
begin
  if proc1_$as_id <> 0 then
    proc2_$info_table[proc2_$pid_to_index[proc1_$current]].cleanup_flags :=
        proc2_$info_table[proc2_$pid_to_index[proc1_$current]].
        cleanup_flags + [handler_bit];
end;
