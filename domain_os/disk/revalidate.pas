{ DISK_$REVALIDATE - ask a volume's driver to revalidate it.

  Image addresses:
    sau2  0x00E6C060  DISK_$REVALIDATE

  - DISK_$REVALID for the descriptor of the given volume index.

  Status stored: none.
}

procedure disk_$revalidate(vol_idx: integer);
begin
  disk_$revalid(disk_$dvtbl[vol_idx]);
end;
