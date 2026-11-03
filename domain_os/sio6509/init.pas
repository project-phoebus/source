{ SIO6509_$INIT - set up a 6509 console serial channel.

  Image addresses:
    sau2  0x00E3350C  SIO6509_$INIT
    sau3  0x00E31A5C  SIO6509_$INIT

  - The channel record goes into SIO6509_$PTRS for its interrupt vector
    and, with `display_driver' (the keyboard's line), SIO6509_$INT1_RTE
    into the exception vector.
  - The record gets the chip's register block and the SIO descriptor;
    the two configuration bytes go to the control register in turn.
  - A fragment of the SIO_IO module (sio6509/README.md).

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes that nothing addresses

  The frame has 4 bytes: the routine is global (no reserved slot), has no
  result and addresses no frame byte, and every value it computes is a
  register temporary of one statement.  A local held in a register keeps its
  slot, but no local the routine could have (vec, chip, regs) is a
  value the image keeps across statements other than the scaled vec, reused
  as a common subexpression.  Stand-in `unused_4'. }

[section(os_init_proc, os_init_data)]
procedure sio6509_$init(in vec: integer; in chip: integer;
                        var chan: sio6509_$chan_t; in callback: univ_ptr;
                        in config: sio6509_$config_t);
var
  unused_4: integer32;                    { see the TODO }
begin
  sio6509_$ptrs[vec] := addr(chan);

%if display_driver %then
  keybd_vec[vec] := addr(sio6509_$int1_rte);
%endif

  chan.regs := addr(sio[chip]);

  chan.sio_desc := callback;

  chan.regs^.ctrl := config[1];
  chan.regs^.ctrl := config[2];
end;
