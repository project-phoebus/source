{ XPD_$CAPTURE_FAULT - stop the current process for its debugger.

  Image addresses:
    sau2  0x00E5B1EE  XPD_$CAPTURE_FAULT
    sau9  0x3C46231A  XPD_$CAPTURE_FAULT
    sau2  0x00E5B188  xpd_$exec_event (nested)

  - The debug-state record is built in the frame; the fault status and
    the ptrace options decide whether the event (fork, exec, exit,
    image load, signal, single step, another fault) is captured.
  - A BLAST returns at once.
  - A captured event saves the FP state, publishes the record, wakes the
    debugger and suspends until it answers; then the debugger's status,
    signal, PC and FP state are taken back.
  - A step armed stores fault_$single_step as the address space's trace
    status; an ignored event clears the quit inhibit and the signal.

  Status stored (in status_ret):
    the fault status as the debugger left it: an event was captured
}

{ TODO(pascal) 28 frame bytes of XPD_$CAPTURE_FAULT nothing explains

  No instruction addresses the 28 bytes between aux and susp_status; a
  `with' temporary would explain 4 of them.  The stand-in unused_224
  holds the place. }

procedure xpd_$capture_fault(in context: xpd_$regs_ptr_t;
                             in frame: xpd_$sr_pc_ptr_t;
                             in out signal: integer;
                             in out status_ret: proc2_$fault_param_t);
label
  10, 20;
var
  state: xpd_$debug_state_t;
  fp_buf: xpd_$fp_buf_t;
  aux: xpd_$aux_buf_t;
  unused_224: array[1..28] of char;    { the TODO }
  susp_status: status_$t;
  sig: 0..31;
  event_code: 0..15;
  pc: linteger;
  bit_temp: set of 0..15;

  { xpd_$exec_event - whether an exec or invoke is reported.

    - Nested in XPD_$CAPTURE_FAULT.  The fault frame's PC in a copy of
      the process entry becomes the new image's entry point (the register
      block's A0).
    - The event is reported when its code is in the flags; else, with
      flags2 members 2 and 7, as event 0 with signal 5 (member 7 cleared
      in the copy only); else not.

    Status stored: none.
  }

  function xpd_$exec_event(entry: proc2_info_t): boolean;
  begin
    xpd_$exec_event := true;
    state.frame^.pc := state.regs^[9];

    if not (event_code in entry.ptrace_opts.flags) then
      if (2 in entry.ptrace_opts.flags2) and then
         (7 in entry.ptrace_opts.flags2) then begin
        event_code := 0;
        signal := 5;
        entry.ptrace_opts.flags2 := entry.ptrace_opts.flags2 - [7];
      end
      else
        xpd_$exec_event := false;
  end;

begin
  { the debug-state record }
  state.frame := frame;
  state.regs := context;
  state.fp_buf := addr(fp_buf);
  state.aux := addr(aux);
  state.fp_modified := false;

  with proc2_$info_table[proc2_$pid_to_index[proc1_$current]] do begin
    { the event }
    case status_ret.all of
      status_$xpd_target_is_forking: begin
        event_code := 1;
        if event_code in ptrace_opts.flags then
          signal := 0
        else
          goto 20;
      end;
      status_$xpd_target_is_vforking: begin
        event_code := 1;
        bit_temp := ptrace_opts.flags;
        if event_code in bit_temp then
          signal := 1
        else
          goto 20;
      end;
      status_$xpd_target_is_execing: begin
        event_code := 2;
        signal := 0;
        if not xpd_$exec_event(
                 proc2_$info_table[proc2_$pid_to_index[proc1_$current]]) then
          goto 20;
      end;
      status_$xpd_target_is_invoking: begin
        event_code := 2;
        signal := 1;
        if not xpd_$exec_event(
                 proc2_$info_table[proc2_$pid_to_index[proc1_$current]]) then
          goto 20;
      end;
      status_$xpd_target_is_exiting: begin
        event_code := 4;
        bit_temp := ptrace_opts.flags;
        if event_code in bit_temp then
          signal := 0
        else
          goto 20;
      end;
      status_$xpd_target_is_loading_exec_image: begin
        event_code := 5;
        bit_temp := ptrace_opts.flags;
        if event_code in bit_temp then
          signal := 0
        else
          goto 20;
      end;
      status_$xpd_target_is_signalled: begin
        event_code := 5;
        bit_temp := ptrace_opts.flags;
        if event_code in bit_temp then
          signal := 1
        else
          goto 20;
      end;
      fault_$single_step: begin
        pc := state.frame^.pc;
        if 6 in ptrace_opts.flags then begin
          if (pc < ptrace_opts.trace_range_lo) or else
             (pc > ptrace_opts.trace_range_hi) then begin
            event_code := 6;
            goto 10;
          end;
        end
        else if 7 in ptrace_opts.flags then begin
          if (pc >= ptrace_opts.trace_range_lo) and then
             (pc <= ptrace_opts.trace_range_hi) then begin
            event_code := 7;
            goto 10;
          end;
        end
        else begin
          if not (0 in ptrace_opts.flags) then
            goto 20;
          if not ((signal - 1) in ptrace_opts.signal_mask) then
            goto 20;
          event_code := 0;
          goto 10;
        end;
        { another single step }
        fim_$trace_sts[asid].all := fault_$single_step;
        fim_$deliver_trace_fault(asid);
        last_pc := pc;
        goto 20;
      end;
      fault_$blast: begin
        return;
      end;
      otherwise begin
        if not (0 in ptrace_opts.flags) then
          return;
        if not ((signal - 1) in ptrace_opts.signal_mask) then
          return;
        event_code := 0;
      end;
    end;

    { capture }
10:
    xpd_$fp_get_state(state.fp_buf^, state.aux^);
    state_va := addr(state);
    flags.bits := flags.bits + [xpd_pf_suspended];
    pad_94 := lshft(event_code, 8) ! signal;
    fault_param.all := status_ret.all;

    { tell the debugger }
    if 4 in ptrace_opts.flags2 then
      ec_$advance(proc2_$ec[debugger_idx].cr_rec_ec)
    else
      proc2_$awaken_guardian(self_index);

    { stay stopped until continued }
    while xpd_pf_suspended in flags.bits do begin
      discard(proc1_$suspend(level1_pid, susp_status));
      ml_$unlock(ml_$proc2_lock);
      ml_$lock(ml_$proc2_lock);
    end;

    { take back what the debugger set }
    state_va := nil;
    if state.fp_modified then
      xpd_$fp_put_state(state.fp_buf^, state.aux^);
    status_ret.all := fault_param.all;
    signal := pad_94 & 16#FF;
    last_pc := state.frame^.pc;
    flags.bits := flags.bits - [xpd_pf_state_saved];
    sig_mask_2 := [];
    fim_$clear_trace_fault(asid);

    if xpd_pf_trace_pending in flags.bits then begin
      fim_$trace_sts[asid].all := fault_$single_step;
      fim_$deliver_trace_fault(asid);
    end;

    { a signal left pending }
    if signal <> 0 then begin
      sig := signal - 1;
      if sig in sig_blocked.blocked_2 then
        sig_mask_2 := sig_mask_2 + [sig]
      else if not (sig in sig_blocked.blocked_1) then
        return;
    end;

    { ignore }
20:
    fim_$quit_inh[proc1_$as_id] := false;
    signal := 0;
  end;
end;
