{ TIME_$Q_INIT_QUEUE - initialize a time queue.

  Image addresses:
    sau2  0x00E16C5E  TIME_$Q_INIT_QUEUE
    sau4  0x0F817616  TIME_$Q_INIT_QUEUE

  - The queue is emptied, its lock cleared, and its kind and id set.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure time_$q_init_queue(virtual: boolean; queue_id: pinteger;
                             out queue: time_$queue_t);
begin
  queue.head := nil;
  queue.lock := 0;
  queue.virtual := virtual;
  queue.queue_id := queue_id;
end;
