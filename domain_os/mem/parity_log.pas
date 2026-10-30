{ MEM_$PARITY_LOG - count a memory parity error.

  Image addresses:
    sau2  0x00E0ADB0  MEM_$PARITY_LOG
    sau9  0x3C40CC3C  MEM_$PARITY_LOG

  - The error is counted against its board (1 below 3MB, 2 above), then
    against the per-page record of its page, address bits 21..16.
  - With the board size from MMU_CCR (4 or 16 MB), the board is the
    address in MB divided by the size, and a page record matches the
    whole address.
  - With no record for the page, the first record with the lowest count
    (an empty one, if any) is taken over with a count of 1.

  Status stored: none.
}

procedure mem_$parity_log(phys_addr: mem_$phys_addr_t);
  options(val_param);
%if not mem_ccr_board_size %then
const
  mem_board_boundary = 16#300000;
  mem_board_low = 1;
  mem_board_high = 2;
%endif
var
%if mem_ccr_board_size %then
  board_mb: integer;
%endif
  board: integer;
  index: integer;
  min_index: integer;
  min_count: integer;
%if not mem_ccr_board_size %then
  page_id: integer;
%endif
begin
  { the board }
%if mem_ccr_board_size %then
  if not mmu_ccr.small_boards then
    board_mb := mem_board_mb_large
  else
    board_mb := mem_board_mb_small;
  board := rshft(phys_addr.all, 20) div board_mb;
%else
  if phys_addr.all < mem_board_boundary then
    board := mem_board_low
  else
    board := mem_board_high;
%endif

  mem_$mem_rec.board_errors[board] := mem_$mem_rec.board_errors[board] + 1;

%if not mem_ccr_board_size %then
  page_id := phys_addr.byte_1 & 16#3F;

%endif
  { a record of this page, up to the first empty one }
  for index := 1 to mem_page_error_records do begin
    if mem_$mem_rec.page_errors[index].count = 0 then
      exit;
%if mem_ccr_board_size %then
    if mem_$mem_rec.page_errors[index].addr.all = phys_addr.all then begin
%else
    if (mem_$mem_rec.page_errors[index].addr.byte_1 & 16#3F) = page_id then begin
%endif
      mem_$mem_rec.page_errors[index].count :=
        mem_$mem_rec.page_errors[index].count + 1;
      return;
    end;
  end;

  { the record with the lowest count }
  min_index := 1;
  min_count := mem_$mem_rec.page_errors[1].count;
  for index := 2 to mem_page_error_records do
    if mem_$mem_rec.page_errors[index].count < min_count then begin
      min_count := mem_$mem_rec.page_errors[index].count;
      min_index := index;
    end;

  { taken over by this page }
  mem_$mem_rec.page_errors[min_index].count := 1;
  mem_$mem_rec.page_errors[min_index].addr := phys_addr;
end;
