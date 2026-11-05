{ MEM_$ECCC6_LOG - log and count a corrected memory error.

  Image addresses:
    sau6  0x7800B8F4  MEM_$ECCC6_LOG

  - The error goes into the system log with its board and registers,
    counts against the board, and against its page's record: the
    record of the same address and board, else a free record or the
    one with the lowest count, taken over.
  - The result is false once the board has had mem_ecc_error_limit
    errors, when its control field is set to quiet it; else true.
  - The image scales the board, the matching record's index and the
    lowest count's index in 32 bits; the board is a word parameter and
    the two indexes word locals, so those indexes are integer32
    transfers (the loop's reads go through a stepped pointer).

  Status stored: none.
}

function mem_$eccc6_log(board: integer; reg_08: integer;
                        mear: mem_$ecc6_mear_t; mcsr: linteger): boolean;
  options(val_param);
var
  entry: mem_$ecc6_log_entry_t;
  addr_bits: integer32;
  index: integer;
  min_index: integer;
  min_count: integer;
begin
  { the log entry and the board's count }
  entry.board := board;
  entry.reg_08 := reg_08;
  entry.mear := mear.all;
  entry.mcsr := mcsr;
  log_$add(log_$type_ecc6_error, entry, 12);
  mem_$mem_rec.board_errors[integer32(board)] :=
    mem_$mem_rec.board_errors[integer32(board)] + 1;
  if mem_$mem_rec.board_errors[integer32(board)] >= mem_ecc_error_limit
  then begin
    mem[integer32(board)].ctl.bits.mode := mem_ecc6_ctl_quiet;
    mem_$eccc6_log := false;
  end
  else
    mem_$eccc6_log := true;

  { a record of this address and board, up to the first empty one }
  addr_bits := mear.bits.addr;
  for index := 1 to mem_page_error_records do begin
    if mem_$mem_rec.page_errors[index].count = 0 then
      exit;
    if (mem_$mem_rec.page_errors[index].mear.bits.addr = addr_bits)
       and then (mem_$mem_rec.page_errors[index].board = board) then begin
      mem_$mem_rec.page_errors[integer32(index)].count :=
        mem_$mem_rec.page_errors[integer32(index)].count + 1;
      return;
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
  mem_$mem_rec.page_errors[integer32(min_index)].count := 1;
  mem_$mem_rec.page_errors[integer32(min_index)].mear.all := mear.all;
  mem_$mem_rec.page_errors[integer32(min_index)].mcsr := mcsr;
  mem_$mem_rec.page_errors[integer32(min_index)].reg_08 := reg_08;
  mem_$mem_rec.page_errors[integer32(min_index)].board := board;
end;
