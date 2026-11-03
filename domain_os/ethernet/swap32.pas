{ ethernet_swap32 - reverse the byte order of a longword.

  Image addresses:
    sau8  0x03C84804  ethernet_swap32
    sau9  0x3C480404  ethernet_swap32

  - The adapter keeps its longwords low byte first (an 80186 board).
}

function ethernet_swap32(x: integer32): integer32; internal;
begin
  ethernet_swap32 := rshft(x, 24) ! (rshft(x, 8) & 16#FF00) !
                     (lshft(x, 8) & 16#FF0000) ! lshft(x, 24);
end;
