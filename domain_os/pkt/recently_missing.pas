{ PKT_$RECENTLY_MISSING - is a node on the list of nodes that failed to
  answer?

  Image addresses:
    sau2  0x00E128BA  PKT_$RECENTLY_MISSING

  - The list's entries in use are searched for the node.

  Status stored: none.
}

function pkt_$recently_missing(node_id: linteger): boolean;
  options(val_param);
var
  count: integer;
  i: integer;
begin
  pkt_$recently_missing := false;
  count := pkt_$n_missing - 1;
  for i := 0 to count do
    if node_id = pkt_$missing_node[i + 1].node_id then begin
      pkt_$recently_missing := true;
      exit;
    end;
end;
