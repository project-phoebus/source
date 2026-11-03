{ MEM_$ECCC_LOG - log and count a corrected memory error.

  Image addresses:
    sau4  0x0F80B6B4  MEM_$ECCC_LOG

  - The first board, in order, whose controller has an error to report
    is the one served; the others are left for the next call.
  - An uncorrectable error crashes the system (fault_$eccu).
  - A corrected error goes into the system log with its board, counts
    against the board and against its page's record (a free record, or
    the one with the lowest count, is taken for a new page), and the
    controller gets its control word back: reporting on, or quieted once
    the board has had mem_ecc_error_limit errors.

  Status stored: none.
}

{ TODO(pascal) MEM_$ECCC_LOG's frame: 4 bytes unaccounted for

  The SAU4 image's frame is 28 bytes: entry at -8 (its 6 bytes on a
  longword boundary), csr at -12 and ctl at -14 are addressed, and the
  five word locals held in registers account for 10 more.  Four bytes
  are left over, which nothing addresses; no other SAU has this routine
  to show what they were.  No stand-in is declared. }

procedure mem_$eccc_log;
label
  done;
var
  entry: mem_$ecc_log_entry_t;
  csr: mem_$ecc_csr_t;
  ctl: integer;
  board: integer;
  page: integer;
  index: integer;
  min_index: integer;
  min_count: integer;
begin
  for board := 1 to mem_ecc_boards do
    if mem_board_slot[board] <> 0 then begin
      csr := mem[board, mem_board_slot[board]].csr;
      if not (mem_ecc_no_error in csr.flags) then begin
        if mem_ecc_uncorrectable in csr.flags then begin
          crash_system(fault_$eccu);
          return;
        end;

        { the log entry and the board's count }
        entry.board := board;
        entry.csr := csr.all;
        log_$add(log_$type_ecc_error, entry, 6);
        mem_$mem_rec.board_errors[board] :=
          mem_$mem_rec.board_errors[board] + 1;
        if mem_$mem_rec.board_errors[board] >= mem_ecc_error_limit then
          ctl := mem_ecc_ctl_quiet
        else
          ctl := mem_ecc_ctl_report;

        { a record of this page, up to the first empty one }
        page := csr.bits.page;
        for index := 1 to mem_page_error_records do begin
          if mem_$mem_rec.page_errors[index].count = 0 then
            exit;
          if mem_$mem_rec.page_errors[index].addr.ecc.page = page then begin
            mem_$mem_rec.page_errors[index].count :=
              mem_$mem_rec.page_errors[index].count + 1;
            goto done;
          end;
        end;

        { else the record with the lowest count, taken over }
        min_index := 1;
        min_count := mem_$mem_rec.page_errors[1].count;
        for index := 2 to mem_page_error_records do
          if mem_$mem_rec.page_errors[index].count < min_count then begin
            min_count := mem_$mem_rec.page_errors[index].count;
            min_index := index;
          end;
        mem_$mem_rec.page_errors[min_index].count := 1;
        mem_$mem_rec.page_errors[min_index].addr.all := csr.all;
        goto done;
      end;
    end;
  return;

  { the board's controller gets its control word }
done:
  mem[board, mem_board_slot[board]].csr.ctl := ctl;
end;
