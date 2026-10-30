{ rip_$packet_length - the length of a RIP packet of n entries.

  Image addresses:
    sau2  0x00E68864  rip_$packet_length (module-local)

  - The command word and n 6-byte entries: n * 6 + 2, in 16 bits.

  Status stored: none.
}

function rip_$packet_length(entry_count: integer): integer; internal;
begin
  rip_$packet_length := entry_count * 6 + 2;
end;
