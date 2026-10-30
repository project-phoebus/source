{ XPD_$WRITE - write another address space's memory.

  Image addresses:
    sau2  0x00E5BAA6  XPD_$WRITE
    sau9  0x3C462BCE  XPD_$WRITE

  - xpd_$copy_memory from the caller's address space into the given
    one, with no checks.

  Status stored:
    xpd_$copy_memory's status: in either case
}

procedure xpd_$write(in asid: integer; out target_mem: univ xpd_$bytes_t;
                     in len: linteger; in buffer: univ xpd_$bytes_t;
                     out status_ret: status_$t);
begin
  xpd_$copy_memory(asid, integer32(addr(target_mem)), proc1_$as_id,
                   integer32(addr(buffer)), len, status_ret);
end;
