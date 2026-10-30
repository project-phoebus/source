{ ring_8025_copy_to_user - scatter bytes into a caller's buffer vector.

  Image addresses:
    sau9  0x3C487AF6  ring_8025_copy_to_user

  - len bytes from src go into the vector's elements from element idx at
    offset, as far as element iov_max; idx and offset are left where the
    copy ended (offset advanced by the bytes copied when the request ends
    inside an element).

  Status stored: none.
}

procedure ring_8025_copy_to_user(var src: univ integer32; len: integer;
                                 var iov: univ ring_8025_$iov_array_t;
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
      offset := offset + n
    else begin
      offset := 0;
      idx := idx + 1;
    end;
  end;
end;
