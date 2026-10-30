{ PKT_$NEXT_ID - the next short packet id.

  Image addresses:
    sau2  0x00E1248E  PKT_$NEXT_ID

  - Under PKT's spin lock the counter is handed back and advanced, back
    to 1 after 64000 (unsigned).

  Status stored: none.
}

function pkt_$next_id: pinteger;
var
  token: pinteger;
begin
  token := ml_$spin_lock(pkt_$spin_lock);
  pkt_$next_id := pkt_$short_id;
  pkt_$short_id := pkt_$short_id + 1;
  if pkt_$short_id > 64000 then
    pkt_$short_id := 1;
  ml_$spin_unlock(pkt_$spin_lock, token);
end;
