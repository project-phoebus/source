{ ring_$copy_to_user - scatter bytes into a caller's buffer vector.

  Image addresses:
    sau2  0x00E77382  ring_$copy_to_user (module-local)

  - ring_$copy_data's code, the copy's direction reversed.
  - offset := n when the request ends inside an element, as in
    ring_$copy_data.

  Status stored: none.
}

procedure ring_$copy_to_user(var src: integer32; len: integer;
                             var iov: univ ring_$iov_array_t;
                             iov_max: integer; var idx: integer;
                             var offset: integer);
  internal;
var
  to_va: integer32;
  from: integer32;
  remaining: integer;
  off: integer32;
  n: integer;
begin
  from := src;
  remaining := len;

  while (remaining <> 0) and then (iov_max >= idx) do begin
    off := offset;
    to_va := iov[idx].va + off;
    n := min(iov[idx].len - off, remaining);
    os_$data_copy(pkt_$bytes_ptr_t(from)^, pkt_$bytes_ptr_t(to_va)^, n);
    from := from + n;
    remaining := remaining - n;
    if remaining = 0 then
      offset := n
    else begin
      offset := 0;
      idx := idx + 1;
    end;
  end;
end;
