%if ct_atbus_qic02 %then
{ CT_WAIT - wait for the tape drive to end the outstanding command.

  Image addresses:
    sau8  0x03C7A3C2  CT_WAIT

  - With the AT bus adapter (`ct_atbus_qic02'): as the other form, the
    driver's eventcount, timeout ticks of TIME_$CLOCKH and, with
    allow_quit, a quit.  At the interrupt, after a read status, an
    exception or a write filemark, a transfer's DMA is stopped first
    (after an exception during a read or write); then the drive's
    status is read (ct_read_status), after a read status command unless
    the command was one.  A DMA failure ends the wait at once.
  - A time-out or a quit stops the DMA.
  - The command is no longer outstanding, and ct_reading is set.

  Status stored: none.

  Returns:
    ct_read_status's or ct_status_cmd's result: the interrupt came
    0: a file spacing command ended at a filemark
    dma_$stop's status: the DMA did not stop
    status_$ct_controller_timeout: the time ran out
    status_$ct_quit_waiting_for_io: a quit
}

function ct_wait(in timeout: integer32; in allow_quit: boolean): integer32;
var
  quit_ec: ec_$eventcount_ptr_t;
  quit_value: integer;
  status: integer32;
  result: integer32;
  dma_status: status_$t;
begin
  status := 0;
  if allow_quit then begin
    quit_ec := addr(fim_$quit_ec[proc1_$as_id]);
    quit_value := fim_$quit_value[proc1_$as_id] + 1;
  end
  else
    quit_ec := nil;
  case ec_$wait(addr(ct_ec), addr(time_$clockh_ec), quit_ec,
                ct_wait_value, time_$clockh + timeout, quit_value) of
    0: begin
         if (ct_cmd = ct_cmd_read_status) or ct_exception
            or else (ct_cmd = ct_cmd_write_filemark) then begin
           if ct_exception and then ct_dma_active then
             if (ct_cmd = ct_cmd_read) or else (ct_cmd = ct_cmd_write)
             then begin
               dma_$stop(ct_dma_channel, ct_residue, dma_status);
               ct_regs^.dma_reset := 0;
               ct_dma_active := false;
               ct_exception := false;
               if (dma_status.all <> status_$ok) and then
                  (dma_status.all <> status_$dma_did_not_finish) then begin
                 ct_wait := dma_status.all;
                 return;
               end;
             end;
           ct_exception := false;
           if ct_cmd <> ct_cmd_read_status then
             status := ct_status_cmd;
           if status = 0 then
             status := ct_read_status;
           if (status = status_$ct_read_no_data_and_bot)
              or else (status = status_$ct_read_no_data)
              or else (status = status_$ct_read_no_data_and_eot) then
             ct_write_ok := true;
           if status = status_$ct_filemark_detected then
             if (ct_cmd = ct_cmd_file_fwd)
                or else (ct_cmd = ct_cmd_file_rev) then
               status := 0;
         end;
         result := status;
       end;
    1: begin
         if ct_dma_active then begin
           dma_$stop(ct_dma_channel, ct_residue, dma_status);
           ct_dma_active := false;
         end;
         result := status_$ct_controller_timeout;
       end;
    2: begin
         fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
         result := status_$ct_quit_waiting_for_io;
         ct_state := ct_state_none;
         if ct_dma_active then begin
           dma_$stop(ct_dma_channel, ct_residue, dma_status);
           ct_dma_active := false;
         end;
       end;
  end;
  ct_busy := false;
  ct_reading := true;
  ct_wait := result;
end;
%else
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
%endif
