{ log_$read_internal - copy part of the log page to a caller's buffer.

  Image addresses:
    sau2  0x00E17778  log_$read_internal (module-local)
    sau4  0x0F818130  log_$read_internal (module-local)

  - The length is the whole page (1024 bytes) or max_len rounded down to
    even, cut at the page's end; no page mapped, or a start past the
    end, gives 0 bytes.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes unaddressed (stand-in unused_10)

  The frame has 4 bytes that nothing addresses: the reserved slot (4),
  src (4) and i (2) make 10, rounded to 12, not 16.  The conformance
  unit declares the same stand-in (`unknown'). }

procedure log_$read_internal(out buffer: log_$buf_t; offset: pinteger;
                             max_len: pinteger; out actual_len: pinteger);
  internal;
var
  src: log_$buf_ptr_t;
  i: integer;
  unused_10: integer32;                   { the stand-in (TODO) }
begin
  if log_$logfile_ptr = nil then begin
    actual_len := 0;
    return;
  end;

  { the whole page, or max_len made even }
  actual_len := log_$buffer_size;
  if max_len < log_$buffer_size then
    actual_len := max_len & 16#fffe;

  { cut at the page's end }
  if offset + actual_len > log_$buffer_size then
    if offset > log_$buffer_size then
      actual_len := 0
    else
      actual_len := log_$buffer_size - offset;

  { the words }
  src := univ_ptr(integer32(log_$logfile_ptr) + offset);
  for i := 1 to actual_len div 2 do
    buffer[i] := src^[i];
end;
