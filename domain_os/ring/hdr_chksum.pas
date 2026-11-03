{ HDR_CHKSUM - the ring header's checksum.

  Image addresses:
    sau2  0x00E762CA  HDR_CHKSUM
    sau8  0x03C82B9C  HDR_CHKSUM
    sau9  0x3C47E78E  HDR_CHKSUM

  - The header's bytes 13 .. len (from 1) are summed in 16 bits, each
    step doubling the sum before adding the byte; the result is the
    sum's low byte (0 for a header under 13 bytes).
  - A global without `$' in the map.

  Status stored: none.
}

function hdr_chksum(in hdr: univ pkt_$bytes_t; in len: integer): integer;
var
  sum: integer;
  i: integer;
begin
  sum := 0;
  for i := 13 to len do
    sum := sum + sum + ord(hdr[i]);

  hdr_chksum := sum & 16#FF;
end;
