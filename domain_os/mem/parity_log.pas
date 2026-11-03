{ MEM_$PARITY_LOG - count a memory parity error.

  Image addresses:
    sau2  0x00E0ADB0  MEM_$PARITY_LOG
    sau8  0x03C0BC60  MEM_$PARITY_LOG
    sau9  0x3C40CC3C  MEM_$PARITY_LOG

  - The error is counted against its board (1 below 3MB, 2 above), then
    against the per-page record of its page, address bits 21..16.
  - With the board size from MMU_CCR (4 or 16 MB), the board is the
    address in MB divided by the size, and a page record matches the
    whole address.
  - With `mem_board_jumpers' the board, 1 to 4, is the one the memory
    configuration from the SIO's input port puts the address's MB above
    the first in, and a page record matches the address's low 24 bits.
  - With no record for the page, the first record with the lowest count
    (an empty one, if any) is taken over with a count of 1.

  Status stored: none.
}

procedure mem_$parity_log(phys_addr: mem_$phys_addr_t);
  options(val_param);
%if not mem_ccr_board_size and not mem_board_jumpers %then
const
  mem_board_boundary = 16#300000;
  mem_board_low = 1;
  mem_board_high = 2;
%endif
var
%if mem_ccr_board_size %then
  board_mb: integer;
%endif
%if mem_board_jumpers %then
  mb: integer;
  config: integer;
%endif
  board: integer;
  index: integer;
  min_index: integer;
  min_count: integer;
%if mem_board_jumpers %then
  page_id: integer32;
%elseif not mem_ccr_board_size %then
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
%elseif mem_board_jumpers %then

  { TODO(pascal) the board limits' compare widths

    In the SAU8 image every arm's first limit is compared with mb as a
    word and the others as longwords, mb sign-extended once per arm (the
    SAU7's form of this routine does the same with limits four times
    these).  Plain integer limits compile to word compares; what made
    the original's other limits longwords (constants of type integer32,
    an expression of a longword constant) is not known. }

  mb := rshft(phys_addr.all - 16#100000, 20);
  config := ord(sio.ipr_opcr) & mem_config_mask;
  case config of
    16#44, 16#54:
      board := 1;
    16#60, 16#50, 16#64:
      if mb < 1 then
        board := 1
      else if mb < 2 then
        board := 2
      else if mb < 3 then
        board := 3
      else
        board := 4;
    16#20, 16#30, 16#14:
      if mb < 2 then
        board := 1
      else if mb < 4 then
        board := 2
      else if mb < 6 then
        board := 3
      else
        board := 4;
    16#10, 16#40, 16#70:
      if mb < 2 then
        board := 1
      else if mb < 3 then
        board := 2
      else if mb < 4 then
        board := 3
      else
        board := 4;
    4, 0:
      if mb < 2 then
        board := 1
      else if mb < 4 then
        board := 2
      else if mb < 5 then
        board := 3
      else
        board := 4;
    16#24:
      if mb < 2 then
        board := 1
      else if mb < 4 then
        board := 2
      else if mb < 6 then
        board := 3
      else
        board := 4;
    otherwise
      board := 1;
  end;
%else
  if phys_addr.all < mem_board_boundary then
    board := mem_board_low
  else
    board := mem_board_high;
%endif

  mem_$mem_rec.board_errors[board] := mem_$mem_rec.board_errors[board] + 1;

%if mem_board_jumpers %then
  page_id := phys_addr.bits.bits_23_0;
%elseif not mem_ccr_board_size %then
  page_id := phys_addr.byte_1 & 16#3F;

%endif
  { a record of this page, up to the first empty one }
  for index := 1 to mem_page_error_records do begin
    if mem_$mem_rec.page_errors[index].count = 0 then
      exit;
%if mem_ccr_board_size %then
    if mem_$mem_rec.page_errors[index].addr.all = phys_addr.all then begin
%elseif mem_board_jumpers %then
    if mem_$mem_rec.page_errors[index].addr.bits.bits_23_0 = page_id then begin
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
