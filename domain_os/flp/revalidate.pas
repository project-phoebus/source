{ FLP_$REVALIDATE - clear the disk-change flag of a volume's drive.

  Image addresses:
    sau2  0x00E3DC54  FLP_$REVALIDATE
    sau8  0x03C45A20  FLP_$REVALIDATE

  - After a new disk was noticed, the unit may do I/O again; the unit is
    not checked.
  - The AT bus form then seeks the drive one cylinder on, which clears
    the disk change line.

  Status stored: none.
}

%if floppy_atbus %then
procedure flp_$revalidate(in vol: disk_$volume_t);
var
  unit: integer;
begin
  unit := vol.dev_unit;
  flp_disk_change[unit] := false;
  flp_rw_cmd[1] := unit;
  flp_rw_cmd[2] := flp_unit_cyl[unit] + 1;
  flp_rw_cmd[3] := 2;
  flp_rw_cmd[4] := 1;
  flp_rw_cmd[0] := 16#0F;
  discard(excs(flp_rw_cmd, 3, vol));
  flp_unit_cyl[unit] := flp_$sregs[1].w;
end;
%else

procedure flp_$revalidate(in vol: disk_$volume_t);
begin
  flp_disk_change[vol.dev_unit] := false;
end;
%endif
