{ ethernet_copy_data - gather bytes from a caller's buffer vector.

  Image addresses:
    sau8  0x03C873DE  ethernet_copy_data
    sau9  0x3C482FDE  ethernet_copy_data

  - len bytes from vector element idx (from 1) at offset onward go to
    the address in dest, as far as element iov_cnt; idx and offset are
    left where the copy stopped.
  - offset := n when the request ends inside an element.

  Status stored: none.
}

procedure ethernet_copy_data(var iov: univ ethernet_$iov_array_t;
                             iov_cnt: integer; var idx: integer;
                             var offset: integer; var dest: integer32;
                             len: integer);
  internal;
var
  from: integer32;
  to_va: integer32;
  remaining: integer;
  off: integer32;
  n: integer;
begin
  to_va := dest;
  remaining := len;

  while (remaining <> 0) and then (iov_cnt >= idx) do begin
    off := offset;
    from := iov[idx].va + off;
    n := min(iov[idx].len - off, remaining);
    os_$data_copy(pkt_$bytes_ptr_t(from)^, pkt_$bytes_ptr_t(to_va)^, n);
    to_va := to_va + n;
    remaining := remaining - n;
    if remaining = 0 then
      offset := n
    else begin
      offset := 0;
      idx := idx + 1;
    end;
  end;
end;
