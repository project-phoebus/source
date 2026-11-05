{ PARITY_$SET_STATE - note the pages a DMA channel's transfer uses.

  Image addresses:
    sau7  0x3C40CC10  PARITY_$SET_STATE
    sau8  0x03C0C0FC  PARITY_$SET_STATE
    sau9  0x3C40D09A  PARITY_$SET_STATE

  - The channel's flag is cleared and the first count page numbers of
    ppns copied into it, so that PARITY_$CHK can tell which channel a
    failing page belongs to.
  - With `parity_dma_page_pairs' the channel notes the two pages ppn1
    and ppn2, their flags cleared.

  Status stored: none.
}

%if parity_dma_page_pairs %then
procedure parity_$set_state(channel: integer; ppn1: integer32;
                            ppn2: integer32);
  options(val_param);
begin
  with parity_$dma_table[channel] do begin
    ppn[1] := ppn1;
    ppn[2] := ppn2;
    took_error[1] := false;
    took_error[2] := false;
  end;
end;
%else

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
%endif
