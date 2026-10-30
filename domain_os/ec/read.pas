{ EC_$READ - read a level-1 eventcount's value.

  Image addresses:
    sau2  0x00E15214  EC_$READ

  - A fragment of the PROC1_ module (proc1/proc1.pas), as ec/init.pas.

  Status stored: none.
}

function ec_$read(in ec: ec_$eventcount_t): integer32;
begin
  ec_$read := ec.value;
end;
