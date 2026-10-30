{ SIO16550_$INIT - initialize a 16550 port.

  Image addresses:
    sau9  0x3C439A2C  SIO16550_$INIT

  - The DCTE's initialization routine: its unit is the port (0 to 3),
    its I/O descriptor gives the registers and the interrupt.
  - SIO_$INIT makes the port's terminal line (port + 1).
  - The receive, line status and modem interrupts are enabled and
    SIO16550_$INT installed for the device.
  - The enable value is the frame's ier with members 0, 2 and 3 added.
  - The result is the status as a longword.

  Status stored: none.
}

{ TODO(pascal) 6 unaddressed frame bytes (stand-ins unused_10, unused_12)

  Between port's slot and ier the frame has a longword and a word no
  instruction reaches.  The other SAUs have no 16550 driver; pointer
  locals the code keeps in registers (the I/O descriptor, the channel)
  are the lead.  The stand-ins hold the place. }

[section(os_init_proc, os_init_data)]
function sio16550_$init(var dcte: dcte_t): integer32;
var
  vtable: static sio16550_$vtable_t := [
    unused_00 := [nil, nil, nil, nil, nil],
    driver := [output_char := addr(sio16550_$xmit),
               set_params := addr(sio16550_$set_line),
               inq_params := addr(sio16550_$inq_line),
               set_break := addr(sio16550_$set_break)],
    name := ['s', 'i', 'o', chr(0)]];
  status: status_$t;
  port: pinteger;
  unused_10: integer32;                   { the stand-ins (TODO) }
  unused_12: integer;
  ier: sio16550_$bits_t;
begin
  port := dcte.cnum;
  if port > sio16550_$max_port then begin
    sio16550_$init := status_$io_illegal_unit_number;
    return;
  end;

  with chans[port] do begin
    regs := sio16550_$regs_ptr_t(
              sio16550_$io_desc_ptr_t(dcte.disk_dinit)^.csr.va);
    line_flags := [];
    flags := 0;
    chan_flags := [];
  end;

  sio_$init(port + 1, addr(chans[port]), vtable, chans[port].sio_desc,
            io_$dcte_crash_line in dcte.config_flags, status);
  if status.all <> status_$ok then begin
    sio16550_$init := status.all;
    return;
  end;

  ier.s := ier.s + [sio16550_$ier_rda, sio16550_$ier_rls,
                    sio16550_$ier_modem];
  chans[port].regs^.ier := ier.c;
  sysbus_$define_int(sio16550_$io_desc_ptr_t(dcte.disk_dinit)^.int.id,
                     addr(sio16550_$int), addr(chans[port]));
  sysbus_$enable_device(sio16550_$io_desc_ptr_t(dcte.disk_dinit)^.int.id);
  sio16550_$init := status_$ok;
end;
