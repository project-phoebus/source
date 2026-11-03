{ LPR_$WRITE - queue a line for the printer.

  Image addresses:
    sau3  0x00E6E848  LPR_$WRITE

  - For the process that acquired the printer: a line of 1 to 284
    characters ending in a line feed or a form feed is copied into a
    block of the circular buffer (waiting for room), and the port's
    interrupt is started when none is expected.

  Status stored:
    status_$ok: the line was queued
    status_$lpr_no_line_printer: the port did not answer
    status_$lpr_not_acquired: the caller did not acquire the printer
    status_$lpr_invalid_string_length: len out of 1..284
    status_$lpr_invalid_string_termination: the line ends otherwise
    CBUF_$ALLOCATE's status: a quit ended the wait for room
}

procedure lpr_$write(in line: univ lpr_$line_t; in len: integer;
                     out status: status_$t);
var
  p: univ_ptr;
begin
  if not lpr_$present then begin
    status.all := status_$lpr_no_line_printer;
    return;
  end;
  if lpr_owner <> proc1_$current then begin
    status.all := status_$lpr_not_acquired;
    return;
  end;
  if (len > lpr_max_line) or else (len <= 0) then begin
    status.all := status_$lpr_invalid_string_length;
    return;
  end;
  case line[len] of
    chr(10), chr(12): { empty };
    otherwise begin
      status.all := status_$lpr_invalid_string_termination;
      return;
    end;
  end;

  p := cbuf_$allocate(lpr_$bcb, len, status);
  if status.all <> status_$ok then
    return;
  lpr_$move_data(line, p, len);
  cbuf_$make_visible(lpr_$bcb, p);
  status.all := status_$ok;
  if not lpr_$int_expected then begin
    lpr_$ir_start_count := lpr_$ir_start_count + 1;
    lpr_$int_expected := true;
    lpr_$enable_int;
  end;
end;
