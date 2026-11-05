{ LOG_$READ2 - read the log page from a byte offset.

  Image addresses:
    sau2  0x00E17828  LOG_$READ2
    sau4  0x0F8181E0  LOG_$READ2
    sau6  0x780182F4  LOG_$READ2
    sau7  0x3C4192E0  LOG_$READ2

  - The by-value entry point of log_$read_internal.

  Status stored: none.
}

procedure log_$read2(out buffer: univ log_$buf_t; offset: pinteger;
                     max_len: pinteger; out actual_len: pinteger);
  options(val_param);
begin
  log_$read_internal(buffer, offset, max_len, actual_len);
end;
