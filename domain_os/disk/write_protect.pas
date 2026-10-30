{ DISK_$WRITE_PROTECT - set or test a volume's write protection.

  Image addresses:
    sau2  0x00E3D956  DISK_$WRITE_PROTECT

  - Mode 0 sets the volume's write-protect bit; mode 1 tests it; any
    other mode does nothing.

  Status stored:
    status_$ok: otherwise
    status_$disk_write_protected: mode 1, the bit set
}

procedure disk_$write_protect(mode: integer; vol_idx: integer;
                              out status: status_$t);
begin
  status.all := status_$ok;

  with disk_$dvtbl[vol_idx] do
    case mode of
      disk_$write_protect_set:
        as_options := as_options + [0];
      disk_$write_protect_test:
        if 0 in as_options then
          status.all := status_$disk_write_protected;
    end;
end;
