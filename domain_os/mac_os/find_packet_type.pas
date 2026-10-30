{ mac_os_$find_packet_type - the index of the table entry whose range
  holds a packet type.

  Image addresses:
    sau2  0x00E0B202  mac_os_$find_packet_type (module-local)

  - The result is the index (from 0) of the first of the first count
    entries whose range holds the type (unsigned, both bounds
    inclusive), or -1.
  - The frame is mac_os_$check_range_overlap's (its TODO(pascal)).

  Status stored: none.
}

function mac_os_$find_packet_type(pkt_type: linteger;
                                  in table: mac_os_$pkt_type_array_t;
                                  count: integer): integer; internal;
var
  i: integer;
  unused_e: integer;                      { stand-in: the TODO(pascal) in
                                            mac_os/check_range_overlap.pas }
begin
  for i := 0 to count - 1 do
    with table[i] do
      if (pkt_type >= range.range_low)
         and then (pkt_type <= range.range_high) then begin
        mac_os_$find_packet_type := i;
        return;
      end;

  mac_os_$find_packet_type := -1;
end;
