{ MT_$PURGE_PB - unwire a request block's pages and, when asked, free
  the block.

  Image addresses:
    sau3  0x00E709E4  MT_$PURGE_PB
    sau4  0x0F87D75C  MT_$PURGE_PB
    sau5  0x00E7654E  MT_$PURGE_PB

  - The pages are unwired once (MT_$PB_WIRED clears its member): the
    header's page, then the buffer's.  A finished read's pages are
    touched when the unit is not purging.
  - PBU2_$UNWIRE's statuses are ignored.

  Status stored: none.
}

procedure mt_$purge_pb;
var
  len: linteger;
  status: status_$t;
  id: integer;
  touch: boolean;
  hdr_len: integer;
begin
  with pb^, mt_$scb.units[unit] do begin
    if mt_$pb_wired(pb^) then begin
      id := pbu_unit;
      touch := not (mt_unit_purging in flags.bits) and (op = mt_op_read);
      hdr_len := 0;
      if header <> 0 then begin
        pbu2_$unwire(id, mt_$buffer_ptr_t(header)^, 1024, touch,
                     status);
        hdr_len := 1024;
      end;
      len := npages * 1024 - hdr_len - 1;
      pbu2_$unwire(id, mt_$buffer_ptr_t(buffer)^, len, touch, status);
    end;
    if release then begin
      pb^.flags := [];
      mt_$enq(mt_$scb.free_q, pb);
    end;
  end;
end;
