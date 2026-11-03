{ time_$q_remove_internal - unlink a queue element.

  Image addresses:
    sau2  0x00E16B70  time_$q_remove_internal (module-local)
    sau4  0x0F817528  time_$q_remove_internal (module-local)

  Assume we're called with the queue's spin lock held.

  - The walk from the head finds the element and unlinks it, clearing
    its link and its in-queue flag.

  Status stored:
    status_$ok: unlinked
    time_$q_elem_not_in_use: the element is not queued
    time_$q_elem_not_found: not found on this queue
}

[section(wired_proc, wired_data)]
procedure time_$q_remove_internal(var queue: time_$queue_t;
                                  var elem: time_$queue_elem_t;
                                  out status: status_$t);
  internal;
var
  cur: time_$queue_elem_ptr_t;
  prev: time_$queue_elem_ptr_t;
begin
  if not (0 in elem.flags) then begin
    status.all := time_$q_elem_not_in_use;
    return;
  end;

  { find the element and its predecessor }
  cur := queue.head;
  prev := nil;
  repeat
    if cur = nil then begin
      status.all := time_$q_elem_not_found;
      return;
    end;
    if cur = addr(elem) then
      exit;
    prev := cur;
    cur := cur^.next;
  until false;

  if prev = nil then
    queue.head := elem.next
  else
    prev^.next := elem.next;
  elem.next := nil;
  elem.flags := elem.flags - [0];
  status.all := status_$ok;
end;
