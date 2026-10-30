{ HINT_$GET_HINTS - list the hints for an object.

  Image addresses:
    sau2  0x00E49966  HINT_$GET_HINTS

  - The key is the UID's low 20 bits.  The hints of the key's slot, up
    to its first empty one, are copied to the list (for a key other
    than 0 and a published hint file).
  - Unless one was the object's own node, or the key is 4 or less, a
    hint for that node follows; one for the local node always ends it.
    The result is the count without that last one, plus one.

  Status stored: none.
}

{ TODO(pascal) frame bytes beyond the locals (stand-in unused_24)

  The SAU2 frame is never addressed (the locals are held in registers);
  their slots explain 14 of its bytes, and what the other 20 held is not
  known.  The stand-in fills the frame to the image's size. }

function hint_$get_hints(in uid: uid_$t;
                         out addresses: hint_$addr_list_t): integer;
var
  key: linteger;
  count: integer;
  found_self: boolean;
  s: integer;
  j: integer;
  unused_24: array[1..5] of integer32;    { the stand-in (TODO) }
begin
  count := 1;
  found_self := false;
  key := uid.low & 16#FFFFF;
  if (key <> 0) and then (hint_$hintfile_ptr <> nil) then

    with hint_$hintfile_ptr^.buckets[key & 16#3F] do
      for s := 1 to 3 do
        with slots[s] do
          if key = uid_low_masked then begin
            for j := 1 to 3 do
              with addrs[j] do begin
                if node_id = 0 then exit;
                addresses[j] := addrs[j];
                if not found_self then found_self := key = node_id;
                count := count + 1;
              end;
            exit;
          end;

  if (not found_self) and then (key > 4) then begin
    addresses[count].node_id := key;
    addresses[count].flags := 0;
    count := count + 1;
  end;

  addresses[count].node_id := node_$me;
  addresses[count].flags := 0;
  hint_$get_hints := count;
end;
