{ cold_set_root - point root table entries at segment tables.

  Image addresses:
    sau7  0x010029EC  cold_set_root (module-local)
    sau9  0x040030D4  cold_set_root (module-local)

  - Entries first .. first + count - 1 of the root table (RARS's page,
    physical 0x4001C00, 4 bytes each) get table physical addresses from
    pa on, a page apart, with the low 4 bits cleared and descriptor type
    3 (valid, 8-byte descriptors).

  Status stored: none.
}

procedure cold_set_root(first: integer; pa: integer32; count: integer);
  internal;
var
  i: 0..255;
  e: os_cold_root_ptr_t;
  last: integer;
begin
  last := first + count - 1;
  for i := first to last do begin
    e := os_cold_root_ptr_t(os_cold_rars_pa + i * 4);
    e^.all := pa & (-16);
    e^.flags := e^.flags + [0, 1];         { the type: 3 }
    pa := pa + 1024;
  end;
end;
