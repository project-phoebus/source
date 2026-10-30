{ PKT_$COPY_TO_PA - copy a packet's data into network data pages.

  Image addresses:
    sau2  0x00E1251C  PKT_$COPY_TO_PA

  - Under a cleanup handler, a data page for each 1024 bytes, mapped,
    filled and unmapped; a failed mapping crashes the system.
  - A fault unmaps the page still mapped, gives back every page taken
    and is signaled on.

  Status stored:
    status_$ok: the data were copied
    a fault's status: the copy faulted
}

{ TODO(pascal) PKT_$COPY_TO_PA reaches buffers_out[buf_count] through a stepped pointer

  The loop reaches the page slot through a pointer formed before the
  loop as buffers_out's address and stepped by 4 at the top of each
  pass, before the use, while buf_count itself is counted in its frame
  word, which the cleanup path reads.  This is the strength reduction of
  a `while' loop's index, as in NETBUF_$RTN_PKT (see the TODO(pascal) in
  netbuf/rtn_pkt.pas), here with the variable kept as well; stepped
  pointers are otherwise seen for `for' loops only. }

procedure pkt_$copy_to_pa(in src_va: univ pkt_$bytes_t; len: integer;
                          out buffers_out: pkt_$data_pages_t;
                          out status_ret: status_$t);
  options(val_param);
var
  cleanup_rec: fim_$cleanup_rec_t;
  src_ptr: integer32;
  buf_va: integer32;
  status: status_$t;
  remaining: integer;
  buf_count: integer;
  chunk_size: pinteger;
  i: integer;
begin
  buffers_out[1] := 0;
  buf_va := 0;
  buf_count := 0;
  src_ptr := integer32(addr(src_va));

  status := fim_$cleanup(cleanup_rec);
  if status.all = fault_$cleanup_set then begin
    { a page for each 1024 bytes }
    remaining := len;
    while remaining > 0 do begin
      buf_count := buf_count + 1;
      netbuf_$get_dat(buffers_out[buf_count]);
      netbuf_$getva(buffers_out[buf_count], buf_va, status);
      if status.all <> status_$ok then begin
        crash_system(status);
        exit;
      end;
      chunk_size := min(1024, remaining);
      os_$data_copy(pkt_$bytes_ptr_t(src_ptr)^, pkt_$bytes_ptr_t(buf_va)^,
                    chunk_size);
      discard(netbuf_$rtnva(buf_va));
      buf_va := 0;
      src_ptr := src_ptr + 1024;
      remaining := remaining - 1024;
    end;

    fim_$rls_cleanup(cleanup_rec);
    status_ret.all := status_$ok;
  end
  else begin
    { a fault: give the pages back }
    if buf_va <> 0 then
      discard(netbuf_$rtnva(buf_va));
    for i := 1 to buf_count do
      netbuf_$rtn_dat(buffers_out[i]);

    fim_$signal(status);
    status_ret := status;
  end;
end;
