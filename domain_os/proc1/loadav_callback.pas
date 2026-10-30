{ PROC1_$LOADAV_CALLBACK - update the load averages.

  Image addresses:
    sau2  0x00E14BDA  PROC1_$LOADAV_CALLBACK
    sau9  0x3C416EA0  PROC1_$LOADAV_CALLBACK

  - Each of the three load averages (8.24 fixed point) decays by its
    factor and gains the number of ready processes times its gain: avg
    := (avg div 256 * decay) div 256 + ready * gain.
  - The load-average element's callback (PROC1_$INIT_LOADAV).

  Status stored: none.
}

procedure proc1_$loadav_callback(in elem: univ_ptr);
var
  ready: integer;
begin
  ready := proc1_$ready_count;
  proc1_$loadav[1] := proc1_$loadav[1] div 256 * 16#EB88 div 256
                      + ready * 16#1478;
  proc1_$loadav[2] := proc1_$loadav[2] div 256 * 16#FBC5 div 256
                      + ready * 16#043B;
  proc1_$loadav[3] := ready * 16#016B
                      + proc1_$loadav[3] div 256 * 16#FE95 div 256;
end;
