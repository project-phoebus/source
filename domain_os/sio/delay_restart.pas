{ SIO_DELAY_RESTART - the end of a transmit delay.

  Image addresses:
    sau2  0x00E1C690  SIO_DELAY_RESTART
    sau4  0x0F81D8A4  SIO_DELAY_RESTART
    sau6  0x7801E590  SIO_DELAY_RESTART
    sau7  0x3C42087C  SIO_DELAY_RESTART

  - The TIME queue's callback for a delay SIO_$I_TSTART queued, with
    TIME's two-level argument (a pointer to a cell holding the
    descriptor's pointer).
  - The transmit-active and delay-active state members (0, 4) are
    cleared and the transmission restarted.

  Status stored: none.
}

{ TODO(pascal) SIO_DELAY_RESTART's frame has 8 bytes no object explains

  The frame has 12 bytes: desc's slot (the pointer is register-held and
  keeps its slot) and 8 bytes no instruction reaches.  The stand-ins
  unused_8 and unused_c, two longwords, hold the place: the bytes do not
  start at a multiple of 8 from A6, where an object of 8 bytes or more
  is placed, so the original's objects there were smaller.  No `with'
  temporary fits: the state store and the push use desc's own register.
  Compare TERM_$ENQUEUE_TPAD's 8-byte frame for the same shape with a
  `with' (term/enqueue_tpad.pas). }

[section(wired_proc, wired_data)]
procedure sio_delay_restart(in arg: sio_$desc_ptr_ptr_t);
var
  desc: sio_$desc_ptr_t;
  unused_8: integer32;                    { stand-ins, see the TODO }
  unused_c: integer32;
begin
  desc := arg^;
  desc^.state := desc^.state - [0, 4];
  sio_$i_tstart(desc);
end;
