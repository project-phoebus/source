{ win7_$move_iopb - move a command block from one list to the front of
  another.

  Image addresses:
    sau7  0x3C41AB60  win7_$move_iopb (module-local)

  - The block is from's: a block with no previous one is the head of
    from's list, and from takes its next; another is unlinked from
    between its neighbours, and from is left alone.
  - The lists are linked through the blocks' records (next, prev).

  Status stored: none.
}

procedure win7_$move_iopb(in out from: win7_$iopb_ptr_t;
                          in out onto: win7_$iopb_ptr_t); internal;
var
  p: win7_$iopb_ptr_t;
  n: win7_$iopb_ptr_t;
begin
  p := from;
  if p^.info^.prev = nil then begin
    n := p^.info^.next;
    p^.info^.next := onto;
    if onto <> nil then
      onto^.info^.prev := p;
    onto := p;
    from := n;
    if from <> nil then
      from^.info^.prev := nil;
  end
  else begin
    n := p^.info^.next;
    p^.info^.prev^.info^.next := n;
    if n <> nil then
      n^.info^.prev := p^.info^.prev;
    p^.info^.next := onto;
    p^.info^.prev := nil;
    if onto <> nil then
      onto^.info^.prev := p;
    onto := p;
  end;
end;
