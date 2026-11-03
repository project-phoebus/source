{ LPR_$ACQUIRE - acquire the line printer for the calling process.

  Image addresses:
    sau3  0x00E6E918  LPR_$ACQUIRE
    sau4  0x0F87B706  LPR_$ACQUIRE

  - The process gets the PROC2 cleanup handler 1; the driver's code and
    data are wired (10 pages at most) and the circular buffer is set up
    empty.
  - With auditing on, the acquire is logged (flags 1 for a failure).
  - The PNA form first sets the printer's PBU unit up
    (PBU_$ACQUIRE_INT); its failure is the status, "pbu not present" as
    status_$lpr_no_pna, another with its fail bit set.

  Status stored:
    status_$ok: the printer was acquired
    status_$lpr_no_line_printer: the port did not answer
    status_$lpr_in_use: another process acquired it
    status_$lpr_already_acquired: the caller acquired it before
}

%if lpr_pbu_unit %then
procedure lpr_$acquire(out status: status_$t);
var
  csr_pa: integer32;
  audit_flags: pinteger;
  data_count: integer;
begin
  csr_pa := integer32(addr(pbu_ctl)) - integer32(addr(pbu_io));
  pbu_$acquire_int(lpr_pbu_unit_number, addr(lpr_$int), nil, addr(pbu_ctl),
                   csr_pa, lpr_csr_pages, lpr_sharing, status);
  if status.all <> status_$ok then begin
    if status.all = status_$pbu_not_present then
      status.all := status_$lpr_no_pna
    else
      status.fail := true;
  end
  else if lpr_acquired then begin
    if proc1_$current <> lpr_owner then
      status.all := status_$lpr_in_use
    else
      status.all := status_$lpr_already_acquired;
  end
  else begin
    proc2_$set_cleanup(1);
    lpr_owner := proc1_$current;
    mst_$wire_area(addr(lpr_$proc_start), addr(lpr_$proc_end),
                   lpr_wire_list, 10, lpr_wire_count);
    mst_$wire_area(addr(lpr_$data_start), addr(lpr_$data_end),
                   lpr_wire_list[lpr_wire_count + 1], 10 - lpr_wire_count,
                   data_count);
    lpr_wire_count := lpr_wire_count + data_count;
    lpr_acquired := true;
    lpr_$int_expected := false;
    cbuf_$init_cb(lpr_$bcb, lpr_$buffer, 512);
    status.all := status_$ok;
  end;

  if audit_$enabled then begin
    if status.all = 0 then
      audit_flags := 0
    else
      audit_flags := 1;
    audit_$log_event(audit_$acquire_lpr_eu, audit_flags, status, 0, 0);
  end;
end;
%else
procedure lpr_$acquire(out status: status_$t);
var
  audit_flags: pinteger;
  data_count: integer;
begin
  if not lpr_$present then
    status.all := status_$lpr_no_line_printer
  else if lpr_acquired then begin
    if proc1_$current <> lpr_owner then
      status.all := status_$lpr_in_use
    else
      status.all := status_$lpr_already_acquired;
  end
  else begin
    proc2_$set_cleanup(1);
    lpr_owner := proc1_$current;
    mst_$wire_area(addr(lpr_$proc_start), addr(lpr_$proc_end),
                   lpr_wire_list, 10, lpr_wire_count);
    mst_$wire_area(addr(lpr_$data_start), addr(lpr_$data_end),
                   lpr_wire_list[lpr_wire_count + 1], 10 - lpr_wire_count,
                   data_count);
    lpr_wire_count := lpr_wire_count + data_count;
    lpr_acquired := true;
    lpr_$int_expected := false;
    cbuf_$init_cb(lpr_$bcb, lpr_$buffer, 512);
    status.all := status_$ok;
  end;

  if audit_$enabled then begin
    if status.all = 0 then
      audit_flags := 0
    else
      audit_flags := 1;
    audit_$log_event(audit_$acquire_lpr_eu, audit_flags, status, 0, 0);
  end;
end;
%endif
