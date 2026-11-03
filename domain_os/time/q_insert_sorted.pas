{ time_$q_insert_sorted - insert a queue element in expiry order.

  Image addresses:
    sau2  0x00E16AE8  time_$q_insert_sorted (module-local)
    sau4  0x0F8174A0  time_$q_insert_sorted (module-local)

  Assume we're called with the queue's spin lock held.

  - An element already queued crashes the system ("element already in
    use").  The new element goes in front of the first that does not
    expire before it; the result is whether it became the head.

  Status stored: none.
}

[section(wired_proc, wired_data)]
function time_$q_insert_sorted(var queue: time_$queue_t;
                               var elem: time_$queue_elem_t): boolean;
  internal;
var
  expire: time_$clock_t;
  next: time_$queue_elem_ptr_t;
  prev: time_$queue_elem_ptr_t;
  cur: time_$queue_elem_ptr_t;
  at_head: boolean;
begin
  if 0 in elem.flags then
    crash_system(time_$q_elem_in_use);

  { the first element not earlier than elem }
  next := queue.head;
  prev := nil;
  while next <> nil do begin
    cur := next;
    expire := cur^.expire;
    if sub48(expire, elem.expire) then
      exit;
    prev := cur;
    next := cur^.next;
  end;

  elem.next := next;
  elem.flags := elem.flags + [0];
  at_head := prev = nil;
  if at_head then
    queue.head := addr(elem)
  else
    prev^.next := addr(elem);
  time_$q_insert_sorted := at_head;
end;
