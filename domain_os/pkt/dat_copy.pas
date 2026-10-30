{ PKT_$DAT_COPY - copy a packet's data out of its data pages.

  Image addresses:
    sau2  0x00E12834  PKT_$DAT_COPY

  - Each 1024 bytes' page is mapped (a failure crashes the system),
    copied out and unmapped.

  Status stored: none.
}

{ TODO(pascal) PKT_$DAT_COPY's index i is never formed

  The loop reaches buffers[i] through a pointer formed before the loop
  as buffers' address + 4 and stepped by 4; i itself is kept nowhere.
  The strength reduction of a `while' loop's variable, as
  NETBUF_$RTN_PKT's (see the TODO(pascal) in netbuf/rtn_pkt.pas). }

procedure pkt_$dat_copy(in buffers: pkt_$data_pages_t; len: integer;
                        dest_va: integer32);
  options(val_param);
var
  status: status_$t;
  va: integer32;
  remaining: integer;
  chunk: integer;
  i: integer;                             { never formed: see the TODO }
  unused_14: integer32;                   { stand-in }
begin
  remaining := len;
  i := 1;

  while remaining > 0 do begin
    chunk := min(remaining, 1024);
    netbuf_$getva(buffers[i], va, status);
    if status.all <> status_$ok then
      crash_system(status);
    os_$data_copy(pkt_$bytes_ptr_t(va)^, pkt_$bytes_ptr_t(dest_va)^, chunk);
    discard(netbuf_$rtnva(va));
    remaining := remaining - chunk;
    dest_va := dest_va + chunk;
    i := i + 1;
  end;
end;
