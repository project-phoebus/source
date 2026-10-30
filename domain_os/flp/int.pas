{ FLP_$INT - the floppy controller's interrupt routine.

  Image addresses:
    sau2  0x00E19F6C  FLP_$INT

  - The first three result bytes go into FLP_$SREGS; SENSE INTERRUPT
    STATUS is written when the controller wants a command before any
    byte came.
  - The result is always true.

  Status stored: none.
}

[section(wired_proc, wired_data)]
function flp_$int(in dcte: dcte_t): boolean;
type
  word_t = record
    case integer of
      1: (w: pinteger);                   { 0x00 }
      2: (hi: flp_$byte_t;                { 0x00 }
          lo: flp_$byte_t);               { 0x01 }
  end;
var
  count: integer;
  word: word_t;
  done: boolean;
  unused_c: integer32;                    { stand-in }
  unused_10: integer32;                   { stand-in }
begin
  flp_hw_addr := flp_ctlr_table[dcte.cnum].hw_addr;

  word.w := 0;
  count := 0;
  done := false;

  { the result phase }
  with flp_hw_addr^ do
    repeat
      repeat until 7 in main_status_bits;
      if 6 in main_status_bits then begin
        word.lo := data_reg;
        if count < 3 then begin
          flp_$sregs[count].w := word.w;
          count := count + 1;
        end;
      end
      else if count = 0 then
        data_reg := 8
      else
        done := true;
    until done;

  { ST0 says the drive's status changed }
  if (flp_$sregs[0].w & 7) = 6 then
    flp_disk_change[flp_$sregs[0].w & 3] := true;

  ec_$advance_without_dispatch(flp_$ec);
  flp_$int := true;
end;
