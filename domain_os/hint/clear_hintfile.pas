{ HINT_$clear_hintfile - empty and reinitialize the hint file.

  Image addresses:
    sau2  0x00E31194  HINT_$clear_hintfile (module-local)

  - The hint file is truncated to length 0; its header is set (version
    7, network 0, port 0's type and socket) and every bucket's slots
    cleared.
  - 65 buckets are cleared, one more than the hash selects.

  Status stored: none.
}

{ TODO(pascal) two word fields copied as one longword

  The SAU2 image copies the port's type and socket words into the
  header's +0x08 and +0x0A as one longword, as HINT_$ADD_NET does;
  two field assignments, as written here, give two word copies in dpc.
  Which form the original had is not settled. }

{ TODO(pascal) 16 unaddressed frame bytes (stand-in unused_20)

  Besides the reserved slot, status, the three indices and truncated,
  the SAU2 frame has 16 bytes nothing addresses: four pointer locals or
  four `with' temporaries would fill them. }

[section(os_init_proc, os_init_data)]
procedure hint_$clear_hintfile; internal;
var
  status: status_$t;
  b: integer;
  s: integer;
  k: integer;
  truncated: boolean;
  unused_20: array[1..4] of integer32;    { the stand-in (TODO) }
begin
  ast_$truncate(hint_$hintfile_uid, 0, 0, truncated, status);

  with hint_$data_hintfile_ptr^ do begin
    version := 7;
    net_port := 0;
    port_type := route_$portp[0]^.port_type;
    socket := route_$portp[0]^.socket;
    for b := 0 to 64 do
      with buckets[b] do
        for s := 1 to 3 do begin
          slots[s].uid_low_masked := 0;
          for k := 1 to 3 do begin
            slots[s].addrs[k].flags := 0;
            slots[s].addrs[k].node_id := 0;
          end;
        end;
  end;
end;
