{ XPD_$READ - read another address space's memory.

  Image addresses:
    sau2  0x00E5BA70  XPD_$READ

  - xpd_$copy_memory from the given address space into the caller's,
    with no checks.

  Status stored:
    xpd_$copy_memory's status: in either case
}

procedure xpd_$read(in asid: integer; in target_mem: univ xpd_$bytes_t;
                    in len: linteger; out buffer: univ xpd_$bytes_t;
                    out status_ret: status_$t);
begin
  xpd_$copy_memory(proc1_$as_id, integer32(addr(buffer)), asid,
                   integer32(addr(target_mem)), len, status_ret);
end;
