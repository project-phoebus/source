{ PKT_$NEXT_LONG_ID - the next long packet id.

  Image addresses:
    sau2  0x00E124DC  PKT_$NEXT_LONG_ID

  - Under PKT's spin lock the counter is handed back and advanced; it
    does not wrap.

  Status stored: none.
}

function pkt_$next_long_id: integer32;
var
  token: pinteger;
begin
  token := ml_$spin_lock(pkt_$spin_lock);
  pkt_$next_long_id := pkt_$long_id;
  pkt_$long_id := pkt_$long_id + 1;
  ml_$spin_unlock(pkt_$spin_lock, token);
end;
