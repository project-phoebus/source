{ CT_WAIT - wait for the controller to end the outstanding command.

  Image addresses:
    sau5  0x00E770A8  CT_WAIT

  - The wait is on the module's eventcount for the last command's value,
    the clock's time-out, and (when allowed) a quit of the current
    process.  The driver's direction then goes back to reading.
  - A read that found no data marks where writing may begin.
  - The quit's wait value is truncated to a word.

  Returns:
    ct_decode_status's result: the controller ended the command
      ("filemark detected" is 0 after a file spacing command)
    status_$ct_controller_timeout: the time-out passed
    status_$ct_quit_waiting_for_io: a quit (the transfer state cleared)

  Status stored: none.
}

function ct_wait(in timeout: integer32; in allow_quit: boolean): integer32;
var
  quit_ec: ec_$eventcount_ptr_t;
  quit_value: integer;
  status: integer32;
begin
  if allow_quit then begin
    quit_ec := addr(fim_$quit_ec[proc1_$as_id]);
    quit_value := fim_$quit_value[proc1_$as_id] + 1;
  end
  else
    quit_ec := nil;

  case ec_$wait(addr(ct_ec), addr(time_$clockh_ec), quit_ec,
                ct_wait_value, time_$clockh + timeout, quit_value) of
    0: begin
         status := ct_decode_status;
         if (status = status_$ct_read_no_data_and_bot)
            or else (status = status_$ct_read_no_data)
            or else (status = status_$ct_read_no_data_and_eot) then
           ct_write_ok := true;
         if status = status_$ct_filemark_detected then
           if (ct_cmd = ct_cmd_file_fwd)
              or else (ct_cmd = ct_cmd_file_rev) then
             status := 0;
       end;
    1: begin
      status := status_$ct_controller_timeout;
    end;
    2: begin
         fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
         status := status_$ct_quit_waiting_for_io;
         ct_state := ct_state_none;
       end;
  end;
  ct_reading := true;
  ct_wait := status;
end;
