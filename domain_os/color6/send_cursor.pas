{ color6_send_cursor - give the board a cursor command.

  Image addresses:
    sau7  0x3C483790  color6_send_cursor (module-local)

  - The command word, its length in words, the cursor's number, size,
    two longword operands and hot spot, then the image's and the
    mask's words: height of each, twice that for a cursor wider than 16.
  - The FIFO is waited for before and after (COLOR6_$BUSY_WAIT).

  Status stored:
    status_$ok: the command was given
    COLOR6_$BUSY_WAIT's status: the board did not take it
}

procedure color6_send_cursor(dcte: color6_$dcte_ptr_t; cnum: integer;
                             width: pinteger; height: integer;
                             op_1: integer32; op_2: integer32;
                             hot_x: integer; hot_y: integer;
                             image: color6_$bitmap_ptr_t;
                             mask: color6_$bitmap_ptr_t;
                             out status: status_$t);
  internal;
var
  regs: color6_$regs_ptr_t;
  n: integer;
  fifo_l: color6_$fifo_long_ptr_t;
  i: integer;
begin
  status.all := status_$ok;
  regs := dcte^.info^.regs;
  color6_$busy_wait(dcte, status);
  if status.all <> status_$ok then
    return;
  with regs^ do begin
    fifo := color6_$cmd_cursor;
    if width > 16 then
      n := height * 2
    else
      n := height;
    fifo := n * 2 + 10;
    fifo := 0;
    fifo := cnum;
    fifo := width;
    fifo := height;
    fifo_l := addr(fifo);
    fifo_l^ := op_1;
    fifo_l^ := op_2;
    fifo := hot_x;
    fifo := hot_y;
    for i := 1 to n do
      fifo := image^[i];
    for i := 1 to n do
      fifo := mask^[i];
  end;
  color6_$busy_wait(dcte, status);
end;
