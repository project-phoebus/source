{ MEM_$INIT - count the memory boards.

  Image addresses:
    sau4  0x0F80B608  MEM_$INIT
    sau6  0x7800B860  MEM_$INIT
    sau7  0x3C40C5D4  MEM_$INIT
    sau8  0x03C0BBC8  MEM_$INIT
    sau9  0x3C40CC00  MEM_$INIT

  - The board size is 4 MB when MMU_CCR's bit 3 is set, else 16 MB;
    MEM_$MEM_REC's board count is MEM_$SIZE in MB divided by it,
    rounded up.
  - With `mem_board_jumpers' the board count, 1 to 4, is the memory
    configuration's from the SIO's input port.
  - With `ecc_memory' the boards are the controllers that answer a probe,
    one per board in the first of its slots that does; each gets the
    control word that turns its reporting on.
  - With `ecc6_memory' the boards are counted from the first while
    their pages answer a probe, each added to MCSR_CONFIG (1 the first,
    2 the second); each counted board's control word gets bits 7..6
    cleared and its reporting on.

  Status stored: none.
}

procedure mem_$init;
%if ecc_memory %then
var
  data: integer32;
  board: integer;
  slot: integer;
  n_boards: integer;
  location: univ_ptr;
begin
  { each board's controller: the first slot that answers }
  n_boards := 0;
  for board := 1 to mem_ecc_boards do begin
    mem_board_slot[board] := 0;
    for slot := 1 to mem_ecc_slots do begin
      location := addr(mem[board, slot].csr);
      if testpage(0, location, data) then begin
        n_boards := n_boards + 1;
        mem_board_slot[board] := slot;
        exit;
      end;
    end;
  end;
  mem_$mem_rec.n_boards := n_boards;

  { reporting on }
  for board := 1 to mem_ecc_boards do
    if mem_board_slot[board] <> 0 then
      mem[board, mem_board_slot[board]].csr.ctl := mem_ecc_ctl_report;
end;
%elseif ecc6_memory %then
var
  data: integer;
  board: integer;
  n_boards: integer;
  location: univ_ptr;
begin
  { the boards that answer, from the first }
  n_boards := 0;
  for board := 1 to mem_ecc6_boards do begin
    location := addr(mem[board]);
    if not testpage(0, location, data) then
      exit;
    n_boards := n_boards + 1;
    if board = 1 then
      mcsr_config := mcsr_config + 1
    else
      mcsr_config := mcsr_config + 2;
  end;
  mem_$mem_rec.n_boards := n_boards;

  { reporting on }
  for board := 1 to n_boards do
    mem[board].ctl.all := (mem[board].ctl.all & 16#FF3F) ! mem_ecc6_ctl_report;
end;
%elseif mem_board_jumpers %then
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
