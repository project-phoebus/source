{ MEM_$INIT - count the memory boards.

  Image addresses:
    sau8  0x03C0BBC8  MEM_$INIT
    sau9  0x3C40CC00  MEM_$INIT

  - The board size is 4 MB when MMU_CCR's bit 3 is set, else 16 MB;
    MEM_$MEM_REC's board count is MEM_$SIZE in MB divided by it,
    rounded up.
  - With `mem_board_jumpers' the board count, 1 to 4, is the memory
    configuration's from the SIO's input port.

  Status stored: none.
}

procedure mem_$init;
%if mem_board_jumpers %then
var
  config: integer;
begin
  config := ord(sio.ipr_opcr) & mem_config_mask;
  case config of
    16#44, 16#54:
      mem_$mem_rec.n_boards := 1;
    16#14, 16#70, 16#64:
      mem_$mem_rec.n_boards := 2;
    16#30, 0, 16#40, 16#50:
      mem_$mem_rec.n_boards := 3;
    16#20, 16#24, 4, 16#10, 16#60:
      mem_$mem_rec.n_boards := 4;
    otherwise
      mem_$mem_rec.n_boards := 1;
  end;
end;
%else
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
%endif
