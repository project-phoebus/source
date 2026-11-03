{ SIO6509_$RCV - hand a received character to the SIO line.

  Image addresses:
    sau2  0x00E1D53E  SIO6509_$RCV
    sau3  0x00E1C6B2  SIO6509_$RCV

  - When the chip's status byte's bit 7 says a character is there, it
    goes to SIO_$I_RCV with the line's SIO descriptor and the error
    flags the status's bits 4..6 select from the SIO_IO block's table.
  - A fragment of the SIO_IO module (the 2681 driver's, sio2681/).

  Status stored: none.
}

{ TODO(pascal) bit 7 of status tested on the flags of its byte load

  The SAU2 image branches on the N flag of the status byte's load, bit 7
  of the status register, with no test of its own.  The source below
  writes `(status & 16#80) <> 0', which dpc compiles to a bit test of
  the register.  A test of a boolean bit-7 field
  would read the register a second time, and a signed byte would be
  sign-extended, not cleared first.  Which construct makes the compiler
  branch on the load's flags here is not known. }

[section(wired_proc, wired_data)]
procedure sio6509_$rcv(in chan: sio6509_$chan_t);
var
  status: 0..255;
begin
  status := ord(chan.regs^.ctrl);

  if (status & 16#80) <> 0 then
    sio_$i_rcv(chan.sio_desc, chan.regs^.data,
               sio6509_rcv_flags[rshft(status, 4) & 7]);
end;
