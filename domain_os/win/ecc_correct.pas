{ win_$ecc_correct - correct a data check from the controller's ECC.

  Image addresses:
    sau5  0x00E19878  win_$ecc_correct

  - The pattern's two bytes are flipped in place at ecc_pos: the block
    header for the first 32 bytes, else the data page, mapped at
    WIN_ECC_BUF for the purpose.  WIN_$FIXES counts the corrections.
  - With the descriptor-list controller only.

  Status stored: none.
}

procedure win_$ecc_correct(ctlr: pinteger; ppn: integer32);
  internal;
type
  win_$hdr_bytes_t = array[0..31] of win_$byte_t;
var
  pattern: win_$ecc_pattern_t;
  pos: integer;
  hdr: ^win_$hdr_bytes_t;
  va: integer32;
  i: integer;
  b: win_$byte_t;
  nb: win_$byte_t;
begin
  pattern := win_units[ctlr].regs^.ecc_pattern;
  pos := win_units[ctlr].regs^.ecc_pos;
  hdr := addr(win_cur_req^.header);
  va := mmu_$ptov(ppn);
  mmu_$install(ppn, addr(win_ecc_buf), 0, 16#16);

  for i := 1 to 2 do begin
    b := pattern[i];
    nb := ~b;
    if pos < 32 then
      hdr^[pos] := (b & ~hdr^[pos]) ! (hdr^[pos] & nb)
    else if pos < 1056 then
      win_ecc_buf[pos - 32] := (win_ecc_buf[pos - 32] & nb)
                               ! (~win_ecc_buf[pos - 32] & b);
    pos := pos + 1;
  end;

  if va <> 0 then
    mmu_$install(ppn, univ_ptr(va), 0, 16#16)
  else
    mmu_$remove(ppn);
  mmu_$clr_used(ppn);
  win_$fixes := win_$fixes + 1;
end;
