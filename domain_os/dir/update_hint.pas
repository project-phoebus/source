{ dir_$update_hint - record where a directory operation found its object.

  Image addresses:
    sau2  0x00E4BC76  dir_$update_hint

  - For the network root the hint is param5's network and the UID's low
    20 bits, and none is added for this node's network or 0.

  Status stored: none.
}

procedure dir_$update_hint(in uid: uid_$t; hint1: integer32;
                           hint2: linteger; in redirect: uid_$t;
                           param5: integer32); internal;
var
  hint_data: hint_$addr_t;
begin
  if uid <> name_$root_uid then begin
    hint_data.flags := hint1;
    hint_data.node_id := hint2;
  end
  else begin
    if (param5 = network_$me) or else (param5 = 0) then
      return;
    hint_data.flags := param5;
    hint_data.node_id := redirect.low & 16#FFFFF;
  end;

  hint_$addi(redirect, hint_data);
end;
