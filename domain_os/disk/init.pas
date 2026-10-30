{ DISK_$INIT - initialize the disk module's eventcounts and locks.

  Image addresses:
    sau2  0x00E3C0EA  DISK_$INIT

  - The module's eventcount and every process slot's two eventcounts
    are initialized, then the two locks.

  Status stored: none.
}

procedure disk_$init;
var
  i: integer;
begin
  ec_$init(disk_$ec);

  for i := 1 to 64 do
    with disk_bptbl[i] do begin
      ec_$init(io_ec);
      ec_$init(err_ec);
    end;

  ml_$exclusion_init(disk_$exclusion_2);
  ml_$exclusion_init(disk_$exclusion);
end;
