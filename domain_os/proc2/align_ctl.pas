{ PROC2_$ALIGN_CTL - alignment control: a stub that clears its outputs.

  Image addresses:
    sau2  0x00E41D74  PROC2_$ALIGN_CTL

  - Neither of the first two arguments is read; a word and a longword
    output are cleared.

  Status stored:
    status_$ok: always
}

procedure proc2_$align_ctl(in param_1: integer32; in param_2: integer32;
                           out result_1: pinteger;
                           out result_2: integer32;
                           out status_ret: status_$t);
var
  unused_10: array[1..4] of integer32;    { nothing reaches
                                            it; the TODO(pascal) below }
begin
  result_1 := 0;
  result_2 := 0;
  status_ret.all := status_$ok;
end;

{ TODO(pascal) PROC2_$ALIGN_CTL's frame has 16 bytes nothing addresses
  and the body needs no local: the original's locals are
  not known; the stand-in unused_10 keeps the frame's size. }
