{ PKT_$NOTE_VISIBLE - record whether a node answered.

  Image addresses:
    sau2  0x00E128F6  PKT_$NOTE_VISIBLE

  - A listed node visible again leaves the list (the last entry moved
    in); one still not answering gets a new sequence number.
  - An unlisted node not visible is added, in a free entry or over the
    oldest (sequence numbers compared unsigned).

  Status stored: none.
}

procedure pkt_$note_visible(node: linteger; is_visible: boolean);
  options(val_param);
var
  oldest: integer;
  count: integer;
  i: integer;
begin
  { the list }
  oldest := 1;
  count := pkt_$n_missing - 1;
  for i := 0 to count do
    with pkt_$missing_node[i + 1] do begin
      if node = node_id then begin
        if is_visible then begin
          pkt_$missing_node[i + 1] := pkt_$missing_node[pkt_$n_missing];
          pkt_$n_missing := count;
        end
        else begin
          pkt_$visibility_seq := pkt_$visibility_seq + 1;
          seq_number := pkt_$visibility_seq;
        end;
        return;
      end;
      if seq_number < pkt_$missing_node[oldest].seq_number then
        oldest := i + 1;
    end;

  { a node not on the list }
  if is_visible then
    return;
  if pkt_$n_missing < 10 then begin
    pkt_$n_missing := pkt_$n_missing + 1;
    oldest := pkt_$n_missing;
  end;
  pkt_$missing_node[oldest].node_id := node;
  pkt_$visibility_seq := pkt_$visibility_seq + 1;
  pkt_$missing_node[oldest].seq_number := pkt_$visibility_seq;
end;
