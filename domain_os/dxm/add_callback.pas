{ DXM_$ADD_CALLBACK - queue a routine and a copy of its datum on a DXM
  queue.

  Image addresses:
    sau2  0x00E16FE0  DXM_$ADD_CALLBACK

  - A datum over 12 bytes crashes the system; it is copied into the
    frame, and under the queue's spin lock the routine and the copy go
    at the tail, which advances, and the queue's eventcount advances.
  - With check_dup an entry with the same routine and datum ends it.  A
    full queue shows "(DXM) No room", crashes the system and counts
    DXM_$OVERRUNS.
  - data_size is unsigned.

  Status stored:
    status_$ok: the entry was queued, or was queued already
    status_$dxm_no_more_deferred_execution_queue_slots: the queue is full
}

{ TODO(pascal) 16 frame bytes unexplained (stand-ins unused_20, unused_30)

  16 bytes stay unexplained, 4 between entry and token and 12 below
  match; the stand-ins unused_20 and unused_30 hold their places, the
  KBD and TPAD convention.  Which of the image's register values were
  declared locals is not known (the byte arrays' bases could be pointer
  locals, which would fill some of the 16 bytes); the declaration order
  is chosen to fit the three addressed offsets.  match lives in the
  frame although every read of it is a test (dpc's rule would hold it in
  a register): the routine saves five of D2-D7, the pressure under which
  the original keeps some register candidates in the frame. }

{ TODO(pascal) the byte loop's exit branches to the walk's step

  The image's mismatch branch goes to the step of the walk, past `if
  match then', where an `exit' goes to the statement after the loop, the
  test of match.  With match just cleared that test cannot succeed, so
  the compiler may have threaded the branch through it (as it threads a
  branch to a branch); not a known form.  A `goto' to a label on the
  step gives the image's branch with no such step, but then
  `match := false' would be a dead store the source wrote anyway.  The
  `exit' reading is kept for the store. }

procedure dxm_$add_callback(var queue: dxm_$queue_t;
                            in callback: univ univ_ptr;
                            in data: univ dxm_$data_ptr_t;
                            data_size: dxm_$uword_t;
                            check_dup: boolean;
                            out status: status_$t);
  options(val_param);
var
  num_words: dxm_$uword_t;
  i: dxm_$uword_t;
  local_data: dxm_$data_t;
  idx: dxm_$uword_t;
  j: dxm_$uword_t;
  next_tail: dxm_$uword_t;
  entry: dxm_$entry_ptr_t;
  unused_20: integer32;                   { the stand-in (TODO) }
  token: integer;
  match: boolean;
  unused_30: array[1..3] of integer32;    { the stand-in (TODO) }
begin
  status.all := status_$ok;

  { a datum longer than an entry's crashes the system }
  if data_size > dxm_max_data_size then
    crash_system(status_$dxm_datum_too_large_for_deferred_execution);

  { copy the datum into the frame, in longwords }
  num_words := (data_size + 3) div 4;
  for i := 1 to num_words do
    local_data.longs[i] := data^.longs[i];

  token := ml_$spin_lock(queue.lock);

  { the duplicate check, head to tail }
  if check_dup then begin
    idx := queue.head;
    while idx <> queue.tail do begin
      if univ_ptr(queue.entries^[idx].callback) = callback then begin
        match := true;
        for j := 1 to data_size do
          if local_data.bytes[j] <>
             queue.entries^[idx].data.bytes[j] then begin
            match := false;
            exit;
          end;
        if match then begin
          ml_$spin_unlock(queue.lock, token);
          return;
        end;
      end;
      idx := (idx + 1) & queue.mask;
    end;
  end;

  { the queue is full when the next tail position is the head }
  next_tail := (queue.tail + 1) & queue.mask;
  if next_tail = queue.head then begin
    status.all := status_$dxm_no_more_deferred_execution_queue_slots;
    crash_show_string('(DXM) No room%');
    crash_system(status);
    dxm_$overruns := dxm_$overruns + 1;
    ml_$spin_unlock(queue.lock, token);
    return;
  end;

  { fill the tail entry }
  entry := addr(queue.entries^[queue.tail]);
  entry^.callback := dxm_$callback_t(callback);
  for i := 1 to num_words do
    entry^.data.longs[i] := local_data.longs[i];

  queue.tail := next_tail;
  ml_$spin_unlock(queue.lock, token);
  ec_$advance_without_dispatch(queue.ec);
end;
