{ PKT_$DUMP_DATA - give a packet's data pages back.

  Image addresses:
    sau2  0x00E127E6  PKT_$DUMP_DATA

  - One page for each 1024 bytes of the length, at most four, when the
    packet has data pages at all.

  Status stored: none.
}

procedure pkt_$dump_data(in buffers: pkt_$data_pages_t; len: integer);
  options(val_param);
var
  i: integer;
begin
  if buffers[1] <> 0 then
    for i := 1 to 4 do begin
      if len <= (i - 1) * 1024 then
        exit;
      netbuf_$rtn_dat(buffers[i]);
    end;
end;
