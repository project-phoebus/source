{ TERM_$ENQUEUE_TPAD - hand the queued tablet samples to TPAD_$DATA.

  Image addresses:
    sau2  0x00E72472  TERM_$ENQUEUE_TPAD
    sau9  0x3C479E78  TERM_$ENQUEUE_TPAD

  - The deferred call KBD_$RCV and SUMA_$RCV queue: each sample from
    the consumer index to the producer's goes to TPAD_$DATA, the index
    advanced mod 6.

  Status stored: none.
}

[section(procedure$, data$)]
procedure term_$enqueue_tpad(in buffer_ptr_ptr: tpad_buffer_ptr_ptr_t);
var
  buffer: tpad_buffer_ptr_t;
begin
  buffer := buffer_ptr_ptr^;
  with buffer^ do
    while head <> tail do begin
      tpad_$data(samples[tail]);
      tail := (tail + 1) mod suma_$tpad_buffer_size;
    end;
end;
