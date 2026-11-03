{ iic_do_acquire - acquire a line: start its guardian process and have
  it start the line.

  Image addresses:
    sau3  0x00E71978  iic_do_acquire (module-local)

  - A line that is free only.  A new guardian process serves the line;
    once it is ready it is asked to start the line.  A line that started
    (a self test failure included) is up and owned by asid; an owner
    other than 0 gets the PROC2 cleanup handler 10.  A line that did not
    start is stopped again.
  - When the guardian process cannot be created the status is the
    request's status, which nothing has set.

  Status stored:
    the guardian's status: the line was started, or not
    status_$iic_device_already_acquired: the line is in use
}

procedure iic_do_acquire(line: pinteger; asid: integer;
                         out status: status_$t); internal;
var
  st: status_$t;
  stop_st: status_$t;
begin
  with iic_lines[line] do begin
    case state of
      iic_line_up, iic_line_remote_down: begin
        st.all := status_$iic_device_already_acquired;
      end;
      iic_line_free: begin
        ec_$init(abort_ec);
        iic_guardian_line := line;
        ec_$init(ready_ec);
        ec_$init(done_ec);
        guardian_pid := proc1_$create_p(addr(guardian_process),
                                           16#0C00000D, status);
        if status.all = status_$ok then begin
          discard(ec_$wait(addr(ready_ec), addr(ec_$nil_ec),
                           addr(ec_$nil_ec), 1, 0, 0));
          call_guardian(line, start_ec, st);
          if (st.all = status_$iic_self_test_failure) or else
             (st.all = status_$ok) then begin
            state := iic_line_up;
            owner := asid;
            if asid <> 0 then
              proc2_$set_cleanup(10);
          end
          else
            call_guardian(line, stop_ec, stop_st);
        end;
      end;
    end;
    status := st;
  end;
end;
