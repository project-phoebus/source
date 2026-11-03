{ COLOR_$DISSOC - take the color board back from its owner.

  Image addresses:
    sau4  0x0F87B1C8  COLOR_$DISSOC
    sau5  0x00E72D86  COLOR_$DISSOC

  - Only the owner's call does anything: the instruction queue is
    drained and the pages COLOR_$MAP wired are unmapped; the statuses
    are not read.

  Status stored: none.
}

procedure color_$dissoc;
var
  status: status_$t;
begin
  if color_owner <> proc1_$current then
    status.all := status_$color_illegal_caller
  else begin
    color_$inq_done_wait(status);
    if color_page_count > 0 then
      color_$unmap(0, color_page_count, status);
    color_owner := 0;
  end;
end;
