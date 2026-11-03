{ RING_8025_$LOAD - the driver record's detach entry.

  Image addresses:
    sau8  0x03C8B75E  RING_8025_$LOAD
    sau9  0x3C487362  RING_8025_$LOAD

  - The entry NETWORK_$LOAD calls: nothing is loaded into the adapter.

  Status stored:
    status_$ok: always
}

procedure ring_8025_$load(var unit: pinteger; var unused2: univ integer32;
                          unused3: integer; var unused4: univ integer32;
                          out status: status_$t);
  options(val_param);
begin
  status.all := status_$ok;
end;
