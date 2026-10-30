{ TIME_$Q_FLUSH_QUEUE - empty a time queue.

  Image addresses:
    sau2  0x00E16C80  TIME_$Q_FLUSH_QUEUE

  - The head is cleared; the elements' links and flags are not touched.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure time_$q_flush_queue(var queue: time_$queue_t);
begin
  queue.head := nil;
end;
