{ NET_IO_$COPY_PACKET - copy a packet into fresh network buffers.

  Image addresses:
    sau2  0x00E0E514  NET_IO_$COPY_PACKET
    sau9  0x3C41097C  NET_IO_$COPY_PACKET

  - The payload goes, a 1024-byte page at a time, into data pages from
    NETBUF (from a linear buffer or mapped pages), then the header into
    a header buffer; a failure gives the pages taken back.

  Status stored:
    status_$ok: the packet was copied
    status_$network_transmit_failed: a page could not be mapped
}

{ TODO(pascal) NET_IO_$COPY_PACKET's frame has no room for the failure
  loops' index

  The SAU2 frame, 28 bytes, holds hdr_pa, dst_va and src_va, slots for
  the register-held dst, src (longwords), left and i (words), 24 bytes
  in all, and a 4-byte temporary (the start of the pointer into
  data_pages_out, which the failure loop reloads).  A word j more would
  push the temporary down.  The loop's count is formed in i's register,
  i being dead there.  Readings that fit the frame: the index is a dead
  local such as left (legal, but nothing points to it), or i itself,
  `for i := 1 to i' (the bound is taken before the index is set, ref
  "For", p. 4-89, but the loop lies in the body of the `for' over i,
  whose index may not be changed).  Or a register-held `for' index that
  is never formed gets no slot, against the rule that a register-held
  local keeps its frame slot. }

procedure net_io_$copy_packet(var hdr_src: pkt_$hdr_ptr_t;
                              hdr_len: pinteger;
                              src_data_va: integer32;
                              in src_pages: pkt_$data_pages_t;
                              data_len: pinteger;
                              out hdr_va_out: integer32;
                              out data_pages_out: pkt_$data_pages_t;
                              out status_ret: status_$t);
  options(val_param);
type
  data_ptr_t = ^os_$data_t;
var
  hdr_pa: integer32;
  dst_va: integer32;
  src_va: integer32;
  dst: integer32;
  src: integer32;
  left: pinteger;
  i: integer;
  j: integer;                             { see the TODO }
begin
  status_ret.all := status_$ok;
  left := data_len;
  if data_len = 0 then
    data_pages_out[1] := 0
  else
    for i := 1 to (data_len + 1023) div 1024 do begin
      netbuf_$get_dat(data_pages_out[i]);
      netbuf_$getva(data_pages_out[i], dst_va, status_ret);
      dst := dst_va;
      if status_ret.all <> status_$ok then begin
        { then the shared tail }
        if dst <> 0 then
          discard(netbuf_$rtnva(dst_va));
        for j := 1 to i do
          netbuf_$rtn_dat(data_pages_out[j]);
        status_ret.all := status_$network_transmit_failed;
        return;
      end;

      if src_data_va = 0 then begin
        netbuf_$getva(src_pages[i], src_va, status_ret);
        src := src_va;
        if status_ret.all <> status_$ok then begin
          discard(netbuf_$rtnva(dst_va));
          if src <> 0 then begin
            src_va := src;
            discard(netbuf_$rtnva(src_va));
          end;
          for j := 1 to i do
            netbuf_$rtn_dat(data_pages_out[j]);
          status_ret.all := status_$network_transmit_failed;
          return;
        end;
      end
      else
        src := (i - 1) * 1024 + src_data_va;

      os_$data_copy(data_ptr_t(src)^, data_ptr_t(dst)^, min(1024, left));
      left := left - 1024;
      discard(netbuf_$rtnva(dst_va));
      if src_data_va = 0 then begin
        src_va := src;
        discard(netbuf_$rtnva(src_va));
      end;
    end;

  netbuf_$get_hdr(hdr_pa, hdr_va_out);
  os_$data_copy(hdr_src^, data_ptr_t(hdr_va_out)^, hdr_len);
end;
