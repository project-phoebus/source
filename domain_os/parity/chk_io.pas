{ PARITY_$CHK_IO - tell an I/O driver whether its page took the DMA
  parity error.

  Image addresses:
    sau2  0x00E0B174  PARITY_$CHK_IO
    sau9  0x3C40D05C  PARITY_$CHK_IO

  - Returns 1 or 2 for the one of ppn1 and ppn2 that is a latched DMA
    error's page, the error then cleared; else 0.
  - With `parity_dma_pages' it takes the driver's DMA channel instead:
    2 when PARITY_$CHK flagged the channel, else 0, and the channel's
    pages are forgotten either way.

  Status stored: none.
}

%if parity_dma_pages %then
function parity_$chk_io(channel: integer): integer;
  options(val_param);
var
  result: integer;
begin
  with parity_$dma_table[channel] do begin
    if took_error then
      result := 2
    else
      result := 0;
    npages := 0;
    took_error := false;
  end;
  parity_$chk_io := result;
end;
%else

{ TODO(pascal) 8 frame bytes unexplained (stand-in unused_8)

  The SAU2 frame is 8 bytes and nothing addresses it; the frame model
  explains 4, result's slot and the result variable's.  The other 4 are
  the stand-in unused_8, two words (an integer32 would be longword
  aligned and leave a gap).  Whether the original copied the two
  parameters or declared something else is not known. }

function parity_$chk_io(ppn1: integer32; ppn2: integer32): integer;
  options(val_param);
var
  result: integer;
  unused_8: array[1..2] of integer;       { the stand-in (TODO) }
begin
  if parity_$info.err_status.sau1_dma then begin
    if ppn1 = parity_$info.err_ppn then
      result := 1
    else if ppn2 = parity_$info.err_ppn then
      result := 2
    else
      result := 0;
  end
  else
    result := 0;

  { the match clears the error }
  if result <> 0 then begin
    parity_$info.err_ppn := 0;
    parity_$during_dma := false;
  end;
  parity_$chk_io := result;
end;
%endif
