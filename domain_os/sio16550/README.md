# The SIO16550 subsystem in Domain Pascal

The 16550 UART driver (the serial lines of the SAUs with
`sio16550_lines`, base/config.ins.pas): the map's SIO_IO module there.

## Layout

One module, `sio16550.pas`, `module sio_io, wired_proc, wired_data;`,
its whole body under `%if sio16550_lines` (on the other SAUs SIO_IO is
the 2681's and the 6509's, sio2681/sio2681.pas, whose body is left out
with the part):

| section      | segment             | routines | attribute |
|--------------|---------------------|----------|-----------|
| WIRED_PROC   | SIO_IO, 0x350 bytes | SIO16550_$XMIT, _$INT, _$SET_LINE (nested set_baud), _$SET_BREAK | none (the heading's) |
| OS_INIT_PROC | SIO_IO, 0xD8 bytes  | SIO16550_$INIT | `[section(os_init_proc, os_init_data)]` |
| PROCEDURE$   | SIO_IO, 0x68 bytes  | SIO16550_$INQ_LINE | `[section(procedure$, data$)]` |

Data: the WIRED_DATA segment (0x98 bytes) is the module's variables
(`sio16550.pas` lists them): the four channel records, the baud rate
table, the set of rates the divisor serves, the spin lock, the receive
error table and the character length codes.  The OS_INIT_DATA segment
(0x28 bytes) is SIO16550_$INIT's static driver table.

`sio16550.ins.pas` holds the registers, the register byte records, the
channel record and the headings; the OS_TERM_INIT module includes it
too (KBD_$RESET, SIO_$INIT, TERM_$PCHIST_ENABLE).

## Routines and their fragments

| routine             | fragment |
|---------------------|----------|
| SIO16550_$XMIT      | `xmit.pas` |
| SIO16550_$INT       | `int.pas` |
| SIO16550_$SET_LINE  | `set_line.pas`, with set_baud nested |
| SIO16550_$SET_BREAK | `set_break.pas` |
| SIO16550_$INIT      | `init.pas` |
| SIO16550_$INQ_LINE  | `inq_line.pas` |

## Open items

`TODO(pascal)` comments in the fragments:

- `int.pas`: 4 open frame bytes (stand-in unused_18).
- `init.pas`: 6 open frame bytes (stand-ins unused_10, unused_12).
