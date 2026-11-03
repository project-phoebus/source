{ FLP_$INT - the floppy controller's interrupt routine.

  Image addresses:
    sau2  0x00E19F6C  FLP_$INT
    sau4  0x0F81ABD8  FLP_$INT
    sau8  0x03C1B130  FLP_$INT

  - The first three result bytes go into FLP_$SREGS; SENSE INTERRUPT
    STATUS is written when the controller wants a command before any
    byte came.
  - The AT bus form pauses before each byte and crashes the system when
    the controller is not ready within 2000 polls; the disk change line
    marks the drive's disk changed too.
  - The result is always true.

  Status stored: none.
}

%if floppy_atbus %then
[section(wired_proc, wired_data)]
function flp_$int(in dcte: dcte_t): boolean;
label
  99;
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
  polls: integer;
begin
  flp_hw_addr := flp_ctlr_table[dcte.cnum].hw_addr;

  word.w := 0;
  count := 0;
  done := false;

  { the result phase }
  with flp_hw_addr^ do
    repeat
      polls := 0;
      repeat
        polls := polls + 1;
      until polls = 128;
      polls := 2000;
      while not (7 in main_status_bits) do begin
        polls := polls - 1;
        if polls <= 0 then begin
          crash_system(status_$unrecognized_interrupt);
          goto 99;
        end;
      end;
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

  { the disk change line, or ST0 says the drive's status changed }
  if (7 in flp_hw_addr^.dig_in_bits) or else
     ((flp_$sregs[0].w & 7) = 6) then
    flp_disk_change[flp_$sregs[0].w & 3] := true;

  ec_$advance_without_dispatch(flp_$ec);
99:
  flp_$int := true;
end;
%else

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
%endif
