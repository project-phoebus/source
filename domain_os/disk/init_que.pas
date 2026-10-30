{ DISK_$INIT_QUE - initialize an elevator queue.

  Image addresses:
    sau2  0x00E3C598  DISK_$INIT_QUE

  - Both lists start at their sentinels (nil links, cylinders 16#FFFF);
    the direction is set, the current cylinder and the lock cleared.

  Status stored: none.
}

procedure disk_$init_que(out queue: disk_$que_t);
begin
  queue.list_a := addr(queue.sentinel_a);
  queue.list_b := addr(queue.sentinel_b);
  queue.position.dir := queue.position.dir + [15];
  queue.sentinel_a.next := nil;
  queue.sentinel_a.daddr.cyl := 16#FFFF;
  queue.sentinel_b.next := nil;
  queue.sentinel_b.daddr.cyl := 16#FFFF;
  queue.position.cyl := 0;
  queue.current := 0;
end;
