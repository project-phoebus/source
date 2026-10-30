{ MEM_$INIT - count the memory boards.

  Image addresses:
    sau9  0x3C40CC00  MEM_$INIT

  - The board size is 4 MB when MMU_CCR's bit 3 is set, else 16 MB;
    MEM_$MEM_REC's board count is MEM_$SIZE in MB divided by it,
    rounded up.

  Status stored: none.
}

procedure mem_$init;
var
  board_mb: integer;
begin
  if not mmu_ccr.small_boards then
    board_mb := mem_board_mb_large
  else
    board_mb := mem_board_mb_small;
  mem_$mem_rec.n_boards :=
    (rshft(mem_$size, 20) + (board_mb - 1)) div board_mb;
end;
