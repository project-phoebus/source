{ term_$status_convert - turn a TTY handler, SIO or module 0x33 status
  into the terminal manager's.

  Image addresses:
    sau2  0x00E1AAA8  term_$status_convert (module-local)
    sau3  0x00E1A110  term_$status_convert (module-local)
    sau4  0x0F81BCBC  term_$status_convert (module-local)
    sau7  0x3C41EC94  term_$status_convert (module-local)

  - A status of module 16#33, 16#36 or 16#35 is replaced by its code's
    entry in that module's table (its statics, the map's OS_TERM
    WIRED_DATA segment); others are left.
  - The code is not checked against the table's bounds: large codes
    read the next table's entries or past the block.

  Status stored:
    the table's entry: a status of module 16#33, 16#35 or 16#36
}

[section(wired_proc, wired_data)]
procedure term_$status_convert(in out status: status_$t); internal;
var
  status_35: static array[1..10] of status_$t :=
    [[all := 16#000B0004], [all := 16#000B000D], [all := 16#000B0007],
     [all := 16#000B0001], [all := 16#000B0002], [all := 16#000B0003],
     [all := 16#000B0006], [all := 0], [all := 16#000B0005],
     [all := 0]];                                         { +0x00 }
  status_36: static array[1..11] of status_$t :=
    [[all := 16#000B0004], [all := 16#000B000D], [all := 16#000B0007],
     [all := 16#000B0009], [all := 16#000B000A], [all := 16#000B000B],
     [all := 16#000B000C], [all := 16#000B000F], [all := 16#000B0005],
     [all := 16#000B0006], [all := 16#000B0010]];         { +0x28 }
  status_33: static array[1..4] of status_$t :=
    [[all := 16#000B0004], [all := 16#000B000D], [all := 16#000B0007],
     [all := 16#000B0008]];                               { +0x54 }
begin
  case status.modc of
    16#33: status := status_33[status.code];
    16#36: status := status_36[status.code];
    16#35: status := status_35[status.code];
  end;
end;
