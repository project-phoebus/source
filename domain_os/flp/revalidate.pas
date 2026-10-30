{ FLP_$REVALIDATE - clear the disk-change flag of a volume's drive.

  Image addresses:
    sau2  0x00E3DC54  FLP_$REVALIDATE

  - After a new disk was noticed, the unit may do I/O again; the unit is
    not checked.

  Status stored: none.
}

procedure flp_$revalidate(in vol: disk_$volume_t);
begin
  flp_disk_change[vol.dev_unit] := false;
end;
