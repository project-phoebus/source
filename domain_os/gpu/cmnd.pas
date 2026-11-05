{ GPU_$CMND - run a command list on the graphics processor.

  Image addresses:
    sau5  0x00E741D0  GPU_$CMND
    sau6  0x7807B14A  GPU_$CMND

  - A processor that is not ready is reset; one without the process's
    context is flushed and given the process's pages again.
  - With a time-out (in ticks, above 0) it waits for the processor's
    answer, a page fault (served while page faults are), the clock, the
    process's quit or COLOR2's interrupt.
  - The first time-out or quit clears the abort word and gives 5 more
    ticks; the second time-out resets the processor (in diagnostic mode
    a time-out ends the wait at once).
  - Afterwards the process gives up pages down to its minimum; a failure
    forgets the context; outside diagnostic mode the processor is given
    back.  gpu_status is the processor's last status word or answer.

  Status stored:
    status_$ok: the list ran (the answer 0 or 8), or was sent and
      timeout is not positive
    status_$gpu_not_initialized: the process did not open the processor
    gpu_$lock's status: the processor could not be taken
    gpu_$pio_write's or gpu_$wait_pio_timed's status: the context, the
      set-up or the list could not be sent
    status_$gpu_no_microcode: the answer is 10 or 11, outside diagnostic
      mode
    status_$gpu_error_reported: any other answer
    status_$gpu_device_timeout: the time-out passed
    status_$gpu_wait_quit: the process was told to quit
    gpu_$service_page_fault's status: a page fault could not be served
    status_$gpu_page_fault: a page fault while page faults are not served
    status_$gpu_draw_processor_error: COLOR2's interrupt came
}

{ TODO(pascal) GPU_$CMND's and GPU_$COLD_INIT's constant command lists
  The image copies 32 bytes (GPU_$CMND) and 16 bytes (GPU_$COLD_INIT)
  from constants placed after the routines' code into a frame buffer,
  a structured value assigned whole; Domain Pascal has no structured
  constants in the reference, and the source form that compiles to that
  copy is not known.  The words are assigned one by one here. }

procedure gpu_$cmnd(in cmd_list: univ gpu_$words_t; in count: integer;
                    in timeout: integer; out gpu_status: pinteger;
                    out status_ret: status_$t);
label
  10, 20;
var
  buf: gpu_cmd_buf_t;
  done: integer;
  gpu_stat: pinteger;
  page_status: status_$t;
  first: status_$t;
  p: integer32;
  i: integer;
  retried: boolean;
  reset_needed: boolean;
begin
  status_ret.all := status_$ok;
  if page_max[proc1_$current] <= 0 then
    status_ret.all := status_$gpu_not_initialized
  else if gpu_$user_pid <> proc1_$current then
    gpu_$lock(status_ret);
  if status_ret.all <> status_$ok then
    return;

  if (gpu.status & 16#20) = 0 then
    gpu_$reset;
  if status_ret.all <> status_$ok then
    goto 10;

  { the process's context, when the processor does not have it }
  if context_pid <> proc1_$current then begin
    buf.cmd.op := 16#41E2;
    buf.cmd.len := 0;
    gpu_$pio_write(buf, 2, done, gpu_stat, status_ret);
    if status_ret.all = status_$ok then begin
      gpu_$wait_pio_timed(2, gpu_stat, status_ret);
      if status_ret.all = status_$ok then
        if pages_wired[proc1_$current] > 0 then begin
          p := page_table^[page_head].next;
          buf.cmd.op := 16#41E0;
          buf.cmd.len := 4;
          for i := 1 to pages_wired[proc1_$current] do begin
            repeat
              p := page_table^[p].prev;
            until (page_table^[p].info & 1023) = proc1_$current;
            buf.cmd.arg1 := page_table^[p].info & 16#FFFFFC00;
            buf.cmd.arg2 := lshft(p, 10);
            gpu_$pio_write(buf, 6, done, gpu_stat, status_ret);
            if status_ret.all <> status_$ok then
              exit;
          end;
        end;
    end;
    context_pid := proc1_$current;
  end;
  if status_ret.all <> status_$ok then
    goto 10;

  { the processor's set-up }
  buf.words[1] := 16#41C3;
  buf.words[2] := 2;
  buf.words[3] := 16#8000;
  buf.words[4] := 16#0100;
  buf.words[5] := 16#41C3;
  buf.words[6] := 2;
  buf.words[7] := 16#8001;
  buf.words[8] := 16#0100;
  buf.words[9] := 16#41C3;
  buf.words[10] := 2;
  buf.words[11] := 16#8002;
  buf.words[12] := 16#00A0;
  buf.words[13] := 16#41C3;
  buf.words[14] := 2;
  buf.words[15] := 16#8003;
  buf.words[16] := 16#00A1;
  gpu_$pio_write(buf, 16, done, gpu_stat, status_ret);
  if status_ret.all <> status_$ok then begin
10:
    gpu_status := gpu_stat;
    goto 20;
  end;

  { the eventcounts' targets, and the caller's list }
  wait_vals[gpu_wait_page] := gpu_$page_ec.value + 1;
  wait_vals[gpu_wait_done] := gpu_$done_ec.value + 1;
  wait_vals[gpu_wait_draw] := color2_$int_ec.value + 1;
  gpu_$pio_write(cmd_list, count, done, gpu_stat, status_ret);
  if status_ret.all <> status_$ok then begin
    gpu_status := gpu_stat;
    goto 20;
  end;
  if timeout <= 0 then
    goto 20;

  { the wait }
  wait_ecs[gpu_wait_quit] := addr(fim_$quit_ec[proc1_$as_id]);
  wait_vals[gpu_wait_quit] := fim_$quit_value[proc1_$as_id] + 1;
  wait_vals[gpu_wait_clock] := timeout + time_$clockh + 1;
  retried := false;
  reset_needed := false;
  first.all := status_$ok;
  repeat
    case ec_$waitn(wait_ecs, wait_vals, 5) of
      gpu_wait_page: begin
        if page_faults_ok then begin
          wait_vals[gpu_wait_page] := wait_vals[gpu_wait_page] + 1;
          gpu_$service_page_fault(gpu_stat, page_status);
          if page_status.all <> status_$ok then begin
            if first.all = status_$ok then begin
              first := page_status;
              gpu_status := gpu_stat;
            end;
            reset_needed := true;
            exit;
          end;
        end
        else begin
          status_ret.all := status_$gpu_page_fault;
          exit;
        end;
      end;
      gpu_wait_done: begin
        buf.cmd.op := 16#41C2;
        buf.cmd.len := 2;
        buf.cmd.arg1 := 16#8004;
        gpu_$pio_write(buf, 4, done, gpu_stat, status_ret);
        if status_ret.all = status_$ok then begin
          gpu_$wait_pio(gpu_stat, status_ret);
          if status_ret.all = status_$ok then begin
            gpu_stat := gpu.data;
            if (gpu_stat = 0) or else (gpu_stat = 8) then
              exit;
            if not diag_mode and then
               ((gpu_stat = 10) or else (gpu_stat = 11)) then
              status_ret.all := status_$gpu_no_microcode
            else
              status_ret.all := status_$gpu_error_reported;
          end;
        end;
        gpu_status := gpu_stat;
        exit;
      end;
      gpu_wait_clock: begin
        status_ret.all := status_$gpu_device_timeout;
        if diag_mode then
          exit;
        if retried then begin
          reset_needed := true;
          exit;
        end;
        retried := true;
        first := status_ret;
        gpu.abort_word := 0;
        wait_vals[gpu_wait_clock] := time_$clockh + 5;
      end;
      gpu_wait_quit: begin
        fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
        status_ret.all := status_$gpu_wait_quit;
        if not retried then begin
          retried := true;
          first := status_ret;
          gpu.abort_word := 0;
          wait_vals[gpu_wait_clock] := time_$clockh + 5;
        end;
      end;
      gpu_wait_draw: begin
        first.all := status_$gpu_draw_processor_error;
        reset_needed := true;
        exit;
      end;
      otherwise begin
        exit;
      end;
    end;
  until false;

  if reset_needed then
    gpu_$reset;
  gpu_$unwire_process_pages(page_min[proc1_$current],
                            context_pid = proc1_$current);
  if first.all <> status_$ok then
    status_ret := first;
20:
  if status_ret.all <> status_$ok then
    context_pid := 0;
  if not diag_mode then
    gpu_$unlock;
end;
