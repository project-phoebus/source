{ PARITY_$SET_STATE - note the pages a DMA channel's transfer uses.

  Image addresses:
    sau9  0x3C40D09A  PARITY_$SET_STATE

  - The channel's flag is cleared and the first count page numbers of
    ppns copied into it, so that PARITY_$CHK can tell which channel a
    failing page belongs to.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes unexplained (stand-in unused_c)

  The SAU9 image's frame is 12 bytes and nothing addresses it; the
  frame model explains 8 (i's slot and the `with' temporary of the
  channel's address).  The SAU7's and SAU8's PARITY_$SET_STATE take two
  page numbers and have a 4-byte frame.  What the original declared is
  not known. }

procedure parity_$set_state(channel: integer;
                            in ppns: univ parity_$ppn_list_t;
                            count: pinteger);
  options(val_param);
var
  i: integer;
  unused_c: integer32;                    { the stand-in (TODO) }
begin
  with parity_$dma_table[channel] do begin
    npages := count;
    took_error := false;
    for i := 1 to count do
      pages[i] := ppns[i];
  end;
end;
