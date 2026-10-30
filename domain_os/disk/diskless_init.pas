{ disk_$diskless_init - on a really diskless node, wire the disk code and
  data and start the buffer and disk managers.

  Image addresses:
    sau2  0x00E6B6DC  disk_$diskless_init (module-local)

  - When NETWORK_$REALLY_DISKLESS is set, the OS_DISK code and data runs
    are wired (MST_$WIRE_AREA), DBUF_$INIT and DISK_$INIT run, and the
    flag is cleared, so that it happens once.

  Status stored: none.
}

procedure disk_$diskless_init; internal;
var
  pages: array[1..32] of integer32;
  count: integer;
begin
  if network_$really_diskless then begin
    mst_$wire_area(addr(os_disk_proc), addr(os_disk_proc_end), pages, 32,
                   count);
    mst_$wire_area(addr(os_disk_data), addr(os_disk_data_end), pages, 32,
                   count);
    dbuf_$init;
    disk_$init;
    network_$really_diskless := false;
  end;
end;
