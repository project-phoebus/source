{ DXM_$HELPER_COMMON - the body of a DXM helper process: wait for the
  queue's eventcount, run the queue, forever.

  Image addresses:
    sau2  0x00E171E4  DXM_$HELPER_COMMON

  - Each eventcount value runs the queue once (DXM_$SCAN_QUEUE); a run
    may find it emptied by an earlier one.
  - The endless loop leaves the routine with no epilogue; it has no
    `noreturn'.

  Status stored: none.
}

procedure dxm_$helper_common(var queue: dxm_$queue_t);
var
  wait_val: integer32;
begin
  wait_val := 1;

  { wait for each value, run the queue }
  repeat
    discard(ec_$wait(addr(queue.ec), addr(ec_$nil_ec), addr(ec_$nil_ec),
                     wait_val, 0, 0));
    dxm_$scan_queue(queue);
    wait_val := wait_val + 1;
  until false;
end;
