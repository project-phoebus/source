{ HINT_$add_internal - record a hint in the hint file.

  Image addresses:
    sau2  0x00E49A2C  HINT_$add_internal (module-local)

  Assume we're called with the hint lock held.

  - Nothing is done for node 0 or an unpublished hint file.  A slot of
    the UID's key gets the hint first (the older ones shifted down), or
    a refresh of the flags when it is first already.
  - Without such a slot, an empty or round-robin slot takes the key and
    the hint; the object's own node becomes the second hint, its reverse
    hint recorded by a call to itself.
  - The reverse UID's high longword and top 12 bits are not set (only
    the low 20 are read).

  Status stored: none.
}

{ TODO(pascal) frame bytes beyond the locals (stand-in unused_28)

  The SAU2 image's frame addresses only the reverse UID; with the slots
  of the register-held locals, 20 bytes are left that no local accounts
  for (three pointer locals would be 12, three `with' temporaries of the
  lead 12).  The stand-in fills
  the frame to the image's size. }

procedure hint_$add_internal(in uid: uid_$t; in addresses: hint_$addr_t);
  internal;
var
  key: linteger;
  reverse_uid: hint_$uid_t;
  free_slot: integer;
  s: integer;
  unused_28: array[1..5] of integer32;    { the stand-in (TODO) }
begin
  if addresses.node_id = 0 then return;
  if hint_$hintfile_ptr = nil then return;

  free_slot := 0;
  with hint_$hintfile_ptr^.buckets[uid.low & 16#FFFFF & 16#3F] do begin
    for s := 1 to 3 do
      with slots[s] do begin
        key := uid.low & 16#FFFFF;
        if key = uid_low_masked then begin
          if addrs[1].node_id = addresses.node_id then begin
            addrs[1].flags := addresses.flags;
            return;
          end;
          if addrs[2].node_id <> addresses.node_id then
            addrs[3] := addrs[2];
          addrs[2] := addrs[1];
          addrs[1] := addresses;
          return;
        end;
        if (free_slot = 0) and then (uid_low_masked = 0) then
          free_slot := s;
      end;

    if (key = addresses.node_id)
       and then ((addresses.flags = 0)
                 or else (addresses.flags = route_$port[0].network)) then
      return;

    if free_slot = 0 then begin
      free_slot := hint_$bucket_index;
      if hint_$bucket_index = 3 then
        hint_$bucket_index := 1
      else
        hint_$bucket_index := hint_$bucket_index + 1;
    end;

    with slots[free_slot] do begin
      uid_low_masked := key;
      addrs[1] := addresses;
      if key <> addresses.node_id then begin
        addrs[2].node_id := key;
        addrs[2].flags := addresses.flags;
        reverse_uid.low.node := addresses.node_id;
        hint_$add_internal(reverse_uid.uid, addresses);
      end
      else begin
        addrs[2].flags := 0;
        addrs[2].node_id := 0;
      end;
      addrs[3].flags := 0;
      addrs[3].node_id := 0;
    end;
  end;
end;
