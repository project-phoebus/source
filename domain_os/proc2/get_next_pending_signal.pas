{ proc2_$get_next_pending_signal - the next signal to deliver to a
  process.

  Image addresses:
    sau2  0x00E3EF38  proc2_$get_next_pending_signal (module-local)

  - A pending BLAST SIGAPOLLO first; else the lowest signal pending and
    not blocked (the stop signals left out with flag 11), 0 for none.

  Status stored: none.
}

{ TODO(pascal) get_next_pending_signal's empty-set path returns sig's register

  On the empty-set path the SAU2 image leaves with the result register
  0 from sig's clear, the register sig counts in; no result store on that
  path.  The fragment writes `proc2_$get_next_pending_signal := sig'
  there.  Whether the source assigned the result at entry or left it
  unassigned on that path (returning sig's register by accident) the image
  cannot tell. }

function proc2_$get_next_pending_signal(in entry: proc2_info_t): integer;
var
  sig: integer;
  pending: set of 0..31;
  i: integer;
begin
  sig := 0;
  with entry do begin
    if (18 in sig_mask_2)
       and then (sig_status = fault_$blast) then begin
      proc2_$get_next_pending_signal := proc2_$sig_apollo;
      return;
    end;
    pending := sig_mask_2 - sig_blocked.blocked_2;
    if 11 in flags.bits then
      pending := pending * proc2_$not_stop_signals;
    if pending = [] then begin
      proc2_$get_next_pending_signal := sig;
      return;
    end;
    for i := 1 to 32 do begin
      if sig in pending then
        exit;
      sig := sig + 1;
    end;
    proc2_$get_next_pending_signal := sig + 1;
  end;
end;
