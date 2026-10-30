{ ring_8025_swap16 - exchange the bytes of a word.

  Image addresses:
    sau9  0x3C484C04  ring_8025_swap16

  - The controller's system interface takes and gives its words low
    byte first.
}

function ring_8025_swap16(x: ring_8025_$word_t): ring_8025_$word_t;
  internal;
begin
  ring_8025_swap16 := lshft(x, 8) ! rshft(x, 8);
end;
