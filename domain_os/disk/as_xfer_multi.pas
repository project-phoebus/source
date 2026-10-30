{ DISK_$AS_XFER_MULTI - transfer up to sixteen pages in one chain.

  Image addresses:
    sau2  0x00E6B962  DISK_$AS_XFER_MULTI

  - Every page is wired (a failure unwires the ones already wired), a
    chain of queue blocks filled and handed to DISK_$WRITE_MULTI (op 1)
    or DISK_$READ_MULTI (op 0).
  - Then the pages are unwired and the blocks returned.
  - Each page's status (and a read's header) goes back; the pages past
    those transferred get "transfer not executed".

  Status stored:
    the multi routine's status: the chain was transferred, or not
    status_$disk_buffer_not_page_aligned: a buffer does not start a page
    mst_$wire's status: a page could not be wired
}

procedure disk_$as_xfer_multi(in vol_idx: integer; in count: integer;
                              in op_type: integer;
                              in daddr_array: univ disk_$xfer_daddr_list_t;
                              in info_array: univ disk_$xfer_info_list_t;
                              in buffer_array: univ disk_$xfer_va_list_t;
                              out status_array: univ disk_$xfer_status_list_t;
                              out status: status_$t);
label
  10;
var
  header: disk_$xfer_hdr_list_t;
  page_status: disk_$xfer_status_list_t;
  daddr: disk_$xfer_daddr_list_t;
  buffer: disk_$xfer_va_list_t;
  wired: disk_$xfer_va_list_t;
  st: status_$t;
  tail: disk_$io_req_ptr_t;
  head: disk_$io_req_ptr_t;
  pages_done: integer;
  req: disk_$io_req_ptr_t;
  i: integer;
  j: integer;
begin
  pages_done := 0;

  { gather the pages }
  for i := 1 to count do begin
    daddr[i] := daddr_array[i];
    buffer[i] := buffer_array[i];
    if op_type = 1 then
      header[i] := info_array[i]^;
    if (buffer_array[i] & 16#3FF) <> 0 then begin
      st.all := status_$disk_buffer_not_page_aligned;
      goto 10;
    end;
  end;

  { wire them }
  for i := 1 to count do begin
    wired[i] := mst_$wire(buffer_array[i], st);
    if st.all <> 0 then begin
      for j := 1 to i - 1 do
        wp_$unwire(wired[j]);
      goto 10;
    end;
  end;

  cache_$flush_virtual;
  disk_$get_qblks(count, head, tail);
  req := head;

  { fill the chain }
  for i := 1 to count do begin
    req^.daddr.daddr := daddr[i];
    req^.ppn := wired[i];
    if op_type = 1 then begin
      req^.header.l := header[i];
      req^.owner_op.all := vol_idx;
    end;
    req := req^.next;
  end;

  if op_type = 1 then begin
    disk_$write_multi(false, head, st);
    pages_done := count;
  end
  else
    disk_$read_multi(vol_idx, false, false, head, tail, pages_done, st);

  { collect along the relinked chain }
  req := head;
  for i := 1 to count do begin
    page_status[i] := req^.status;
    wp_$unwire(wired[i]);
    if op_type = 0 then
      header[i] := req^.header.l;
    req := req^.free_next;
  end;

  disk_$rtn_qblks(count, head, tail);

10:
  for i := 1 to count do begin
    status_array[i] := page_status[i];
    if op_type = 0 then
      info_array[i]^ := header[i];
  end;

  for i := pages_done + 1 to count do
    status_array[i].all := status_$disk_transfer_not_executed;

  status := st;
end;
