{ xpd_$copy_memory - copy between two address spaces through a 1K buffer.

  Image addresses:
    sau2  0x00E5B704  xpd_$copy_memory (module-local)

  - Under a cleanup handler the copy runs chunk by chunk, read with the
    source address space selected and written with the destination's;
    a guard fault in either ends it.
  - Both address spaces' trace statuses are then left with the signal
    flag alone, and the caller's address space selected again.

  Status stored:
    status_$ok: copied
    status_$mst_guard_fault: a guard fault
    the fault's status (FIM_$CLEANUP): a fault unwound to the handler
}

procedure xpd_$copy_memory(dst_asid: integer; dst_addr: integer32;
                           src_asid: integer; src_addr: integer32;
                           len: linteger; out status_ret: status_$t); internal;
var
  crec: fim_$cleanup_rec_t;
  buf: os_$data_t;
  dst: integer32;
  src: integer32;
  remaining: linteger;
  cur_asid: integer;
  saved_asid: integer;
begin
  remaining := len;
  saved_asid := proc1_$as_id;
  cur_asid := saved_asid;

  status_ret := fim_$cleanup(crec);
  if status_ret.all = fault_$cleanup_set then begin
    status_ret.all := status_$ok;
    fim_$trace_sts[src_asid].all := 0;
    fim_$trace_sts[dst_asid].all := 0;
    dst := dst_addr;
    src := src_addr;
    while remaining <> 0 do begin
      { read a chunk with the source selected }
      proc1_$set_asid(src_asid);
      cur_asid := src_asid;
      os_$data_copy(xpd_$data_ptr_t(src)^, buf, min(16#400, remaining));
      if fim_$trace_sts[src_asid].all = status_$mst_guard_fault then begin
        status_ret.all := status_$mst_guard_fault;
        exit;
      end;
      { write it with the destination selected }
      proc1_$set_asid(dst_asid);
      cur_asid := dst_asid;
      if remaining > 16#400 then begin
        os_$data_copy(buf, xpd_$data_ptr_t(dst)^, 16#400);
        remaining := remaining - 16#400;
        dst := dst + 16#400;
        src := src + 16#400;
      end
      else begin
        os_$data_copy(buf, xpd_$data_ptr_t(dst)^, remaining);
        remaining := 0;
      end;
      if fim_$trace_sts[dst_asid].all = status_$mst_guard_fault then begin
        status_ret.all := status_$mst_guard_fault;
        exit;
      end;
    end;
    fim_$rls_cleanup(crec);
  end
  else
    fim_$pop_signal(crec);

  fim_$trace_sts[src_asid].all := 0;
  fim_$trace_sts[src_asid].signal_flag := 1;
  fim_$trace_sts[dst_asid].all := 0;
  fim_$trace_sts[dst_asid].signal_flag := 1;

  if saved_asid <> cur_asid then
    proc1_$set_asid(saved_asid);
end;
