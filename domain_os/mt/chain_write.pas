{ MT_$CHAIN_WRITE - write a block with a header from two buffers on a
  magnetic tape unit.

  Image addresses:
    sau3  0x00E707D2  MT_$CHAIN_WRITE
    sau4  0x0F87D54A  MT_$CHAIN_WRITE
    sau5  0x00E7633C  MT_$CHAIN_WRITE

  - MT_$CHAIN_READ's code but for the operation: header and buffer are
    written as one transfer.

  Status stored:
    mt_$queue_request's status: the unit was checked and the write
      queued, or either failed
    status_$mt_header_not_on_header_page: header is not the unit's
      header buffer
    status_$mt_header_or_buffer_misaligned: the header's end or the
      buffer is not on a page boundary
}

procedure mt_$chain_write;
var
  hdr: linteger;
  u: integer;
begin
  u := unit;
  mt_$queue_request(u, mt_op_check, 0, 0, 0, status);
  if status.all = 0 then
    with mt_$scb.units[u] do begin
      hdr := integer32(addr(header));
      if hdr_addr <> 0 then begin
        if hdr <> hdr_addr then begin
          status.all := status_$mt_header_not_on_header_page;
          return;
        end;
        hdr_offset := hdr & 16#3FF;
        hdr := (hdr & 16#FFFC00) + 16#400 - hdr_length;
      end;
      if (((hdr_length + hdr) & 16#3FF) <> 0)
         or else ((integer32(addr(buffer)) & 16#3FF) <> 0) then
        status.all := status_$mt_header_or_buffer_misaligned
      else
        mt_$queue_request(u, mt_op_write, hdr, buffer, hdr_length + length,
                          status);
    end;
end;
