{ LOG_$READ - read the log page from its start.

  Image addresses:
    sau2  0x00E17800  LOG_$READ
    sau4  0x0F8181B8  LOG_$READ

  - log_$read_internal with offset 0 and the length dereferenced.

  Status stored: none.
}

procedure log_$read(out buffer: univ log_$buf_t; in max_len: pinteger;
                    out actual_len: pinteger);
begin
  log_$read_internal(buffer, 0, max_len, actual_len);
end;
