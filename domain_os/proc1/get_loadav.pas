{ PROC1_$GET_LOADAV - the three load averages.

  Image addresses:
    sau2  0x00E14BBA  PROC1_$GET_LOADAV
    sau4  0x0F81542E  PROC1_$GET_LOADAV

  Status stored: none.
}

procedure proc1_$get_loadav(out avg: proc1_$loadav_t);
begin
  avg := proc1_$loadav;
end;
