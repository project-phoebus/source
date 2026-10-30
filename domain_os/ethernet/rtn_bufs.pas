{ ethernet_rtn_bufs - give a received packet's header and data pages
  back to NETBUF.

  Image addresses:
    sau9  0x3C481A3C  ethernet_rtn_bufs

  - A data page of 0 is none.

  Status stored: none.
}

{ TODO(pascal) the stand-in local of ethernet_rtn_bufs

  The routine's frame has four bytes more than its static-link slot, and
  no instruction addresses them.  unused_8 stands for whatever local the
  original declared there. }

procedure ethernet_rtn_bufs(hdr: integer32; dat: integer32);
  internal;
var
  unused_8: integer32;                    { stand-in, see the TODO }
begin
  netbuf_$rtn_hdr(hdr);
  if dat <> 0 then
    netbuf_$rtn_dat(dat);
end;
