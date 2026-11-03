{ AS_$GET_INFO - copy the address-space layout to the caller.

  Image addresses:
    sau2  0x00E583A0  AS_$GET_INFO
    sau8  0x03C60618  AS_$GET_INFO

  - Copies the smaller of req_size and AS_$INFO_SIZE bytes of AS_$INFO,
    and returns that count in actual_size (0 for a req_size of 0 or
    less).

  Status stored: none.
}

{ TODO(pascal) 10 frame bytes unexplained (stand-ins unused_8, unused_c)

  The frame has 12 bytes and no operand addresses them: the `for' index
  keeps a 2-byte slot, and the stand-ins hold the other 10.  One 10-byte
  object would lengthen the frame, so the original's objects were
  smaller.  Two pointer locals for the copy's source and destination
  would take the same place; whether the original declared them is not
  known. }

procedure as_$get_info(out buffer: univ as_$info_bytes_t;
                       in req_size: integer;
                       out actual_size: integer);
var
  i: integer;
  unused_8: integer32;                    { the stand-ins (TODO) }
  unused_c: integer32;
begin
  if req_size <= 0 then begin
    actual_size := 0;
    return;
  end;

  if req_size <= as_$info_size then
    actual_size := req_size
  else
    actual_size := as_$info_size;

  for i := 1 to actual_size do
    buffer[i] := as_$info.bytes[i];
end;
