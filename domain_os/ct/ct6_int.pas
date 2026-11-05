{ CT6_$INT - the second controller's tape completion interrupt.

  Image addresses:
    sau6  0x7807E9A0  CT6_$INT

  - The finished chain is the one the tape's completion mailbox names
    (a crash if the mailbox is empty); its first block is marked done.
  - Along the chain: the first block the controller failed gives its
    status word (ct6_status), the drive's status word and the two counts
    the driver totals, and the count of blocks from it to the chain's
    end (ct6_resid); after a load command every block's drive status and
    counts are taken.
  - The blocks go back to the free list (WIN6_$RTN_IOPBS), the mailbox
    is cleared, the driver's eventcount advanced, and no command is
    outstanding.

  Returns:
    true: always

  Status stored: none.
}

function ct6_$int(in dcte: dcte_t): boolean;
var
  page: ct6_$page_ptr_t;
  first: integer;
  n: integer;
  i: integer;
  failed_at: integer;
begin
  page := ct6_page;
  if page^.tape_done.flag <> 1 then
    crash_system(status_$ct_unexpected_ct_interrupt_fail);
  first := page^.tape_done_iopb div win6_iopb_size;
  page^.iopbs[first].state.kind := ct6_kind_done;
  n := 0;
  i := first;
  ct6_status := 0;
  failed_at := 0;
  ct6_resid := 0;

  { the chain's blocks }
  repeat
    n := n + 1;
    with page^.iopbs[i] do begin
      if (err.sev <> 0) and then (ct6_status = 0) then begin
        failed_at := n;
        ct6_status := status;
        ct_dstat.all := dstat;
        ct_total_2c := ct_total_2c + count_16;
        ct_total_2e := ct_total_2e + count_18;
      end;
      if ct6_loading then begin
        ct_dstat.all := dstat;
        ct_total_2c := ct_total_2c + count_16;
        ct_total_2e := ct_total_2e + count_18;
      end;
      if link = win6_end_of_chain then
        exit;
      i := link div win6_iopb_size;
    end;
  until false;
  if failed_at <> 0 then
    ct6_resid := n - failed_at + 1;

  win6_$rtn_iopbs(n, first, i);
  page^.tape_done.flag := 0;
  ec_$advance_without_dispatch(ct_ec);
  ct_busy := false;
  ct6_$int := true;
end;
