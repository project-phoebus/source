{ CALL_GUARDIAN - pass a request to a line's guardian process and wait
  for its answer.

  Image addresses:
    sau3  0x00E718C0  CALL_GUARDIAN

  - The request is the advance of one of the guardian's eventcounts; the
    answer the advance of the line's done_ec.
  - A quit while waiting aborts the guardian's command (abort_ec) and
    the wait goes on.

  Status stored:
    the guardian's status: the request was carried out, or not
}

procedure call_guardian(in line: pinteger; var request: ec_$eventcount_t;
                        out status: status_$t);
var
  done_value: integer32;
  quit_value: integer32;
  nil_ec: ec_$eventcount_ptr_t;
begin
  with iic_lines[line] do begin
    done_value := ec_$read(done_ec) + 1;
    ec_$advance(request);
    nil_ec := addr(ec_$nil_ec);
    repeat
      quit_value := fim_$quit_value[proc1_$as_id] + 1;
      case ec_$wait(addr(done_ec), addr(fim_$quit_ec[proc1_$as_id]),
                    nil_ec, done_value, quit_value, 0) of
        0: begin
          status := guardian_status;
          return;
        end;
        1: begin
          ec_$advance(abort_ec);
        end;
      end;
    until false;
  end;
end;
