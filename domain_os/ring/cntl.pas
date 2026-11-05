{ RINGLOG_$CNTL - control the ring log.

  Image addresses:
    sau2  0x00E72226  RINGLOG_$CNTL
    sau6  0x780806AA  RINGLOG_$CNTL
    sau7  0x3C488856  RINGLOG_$CNTL
    sau8  0x03C7CAD2  RINGLOG_$CNTL
    sau2  0x00E721CC  ringlog_$stop_logging (nested)
    sau6  0x78080650  ringlog_$stop_logging (nested)
    sau7  0x3C4887FC  ringlog_$stop_logging (nested)
    sau8  0x03C7CA78  ringlog_$stop_logging (nested)

  - Commands 0, 3 and 5 clear the log, wire its buffer and start
    logging, with command 5's node filter or none; 1 and 4 stop logging
    and unwire the buffer.
  - 6, 7 and 8 set the nil, who and mbx socket filters.  Commands 0, 1
    and 2 then copy the whole log out.
  - ringlog_$stop_logging is nested: its `for' index is the parent's i.

  Status stored:
    status_$ok: always
}

[section(procedure$, data$)]
procedure ringlog_$cntl(in cmd: integer; var param: univ ringlog_$cntl_param_t;
                        out status: status_$t);
var
  i: integer;
  end_va: univ_ptr;

  { ringlog_$stop_logging: stop logging, unwire the buffer. }
  procedure ringlog_$stop_logging;
  begin
    if ring_$logging_now then begin
      ring_$logging_now := false;
      for i := 1 to ringlog_$wire_count do
        wp_$unwire(ringlog_$wired_pages[i]);
      ringlog_$wire_count := 0;
    end;
  end;

begin
  status.all := 0;

  case cmd of
    ringlog_$cmd_set_nil_sock: begin
      ringlog_$nil_sock := param.filter;
    end;
    ringlog_$cmd_set_who_sock: begin
      ringlog_$who_sock := param.filter;
    end;
    ringlog_$cmd_set_mbx_sock: begin
      ringlog_$mbx_sock := param.filter;
    end;
    ringlog_$cmd_start, ringlog_$cmd_clear,
    ringlog_$cmd_start_filtered:
      begin
        ringlog_$stop_logging;
        ringlog_$data.index := 0;
        for i := 0 to 99 do
          ringlog_$data.entries[i].nodes.valid := false;
        ringlog_$wire_count := 0;
        end_va := addr(ringlog_$data.unused_11fa);
        mst_$wire_area(addr(ringlog_$data), end_va, ringlog_$wired_pages,
                       10, ringlog_$wire_count);
        if cmd = ringlog_$cmd_start_filtered then
          ringlog_$id := param.id
        else
          ringlog_$id := 0;
        ring_$logging_now := true;
      end;
    ringlog_$cmd_stop_copy, ringlog_$cmd_stop: begin
      ringlog_$stop_logging;
    end;
    ringlog_$cmd_copy: { empty };
  end;

  if cmd in [ringlog_$cmd_start..ringlog_$cmd_copy] then
    param.buf := ringlog_$data;
end;
