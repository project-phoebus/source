{ WIN_$GET_STATS - the statistics entry.

  Image addresses:
    sau2  0x00E19D62  WIN_$GET_STATS
    sau4  0x0F81A9D0  WIN_$GET_STATS
    sau5  0x00E1A156  WIN_$GET_STATS

  - Controller 0, unit 0 gets the 22-byte WIN_$CNT; any other pair 22
    zero bytes.

  Status stored: none.
}

{ TODO(pascal) WIN_$GET_STATS' zero fill

  The SAU2 image stores the 22 zero bytes with one longword store and
  then through a pointer, four longwords and a word: the count fits the
  record's nine fields stored in order with each pair of adjacent words
  merged into a longword, but a pointer walk for consecutive field
  stores is not a known form, and Domain Pascal has no assignment of a
  whole record from a constant that would be a loop or a block fill.
  The field stores are the reading here; the form of the source that
  gives the walk is not known. }

procedure win_$get_stats(cnum: integer; unit: integer;
                         out stats: win_$cnt_t);
var
  zero: win_$cnt_t;
begin
  if (cnum = 0) and then (unit = 0) then
    stats := win_$cnt
  else begin
    zero.xfer_other := 0;
    zero.xfer_op2 := 0;
    zero.not_ready := 0;
    zero.w_0a := 0;
    zero.seek_errors := 0;
    zero.equip_checks := 0;
    zero.w_10 := 0;
    zero.data_checks := 0;
    zero.dma_overruns := 0;
    stats := zero;
  end;
end;
