{ DXM_$SCAN_QUEUE - run every routine queued on a DXM queue.

  Image addresses:
    sau2  0x00E17168  DXM_$SCAN_QUEUE

  - Under the queue's spin lock the head entry is taken and the head
    advanced; the routine is called with the lock released, its datum
    still in the ring though the slot is free again.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes unexplained (stand-in unused_14)

  The 4 bytes below token's word and its 2 bytes of rounding are not
  explained; the stand-in unused_14 holds their place (the KBD and TPAD
  convention). }

procedure dxm_$scan_queue(var queue: dxm_$queue_t);
var
  entry: dxm_$entry_ptr_t;
  callback: dxm_$callback_t;
  data_ptr: univ_ptr;
  token: integer;
  unused_14: integer32;                   { the stand-in (TODO) }
begin
  token := ml_$spin_lock(queue.lock);       { merged with the body's last }

  { run the entries }
  while queue.head <> queue.tail do begin
    entry := addr(queue.entries^[queue.head]);
    callback := entry^.callback;
    data_ptr := addr(entry^.data);
    queue.head := (queue.head + 1) & queue.mask;
    ml_$spin_unlock(queue.lock, token);
    callback^(data_ptr);
    token := ml_$spin_lock(queue.lock);
  end;

  ml_$spin_unlock(queue.lock, token);
end;
