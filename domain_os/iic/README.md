# The IIC subsystem in Domain Pascal

The internet interface controller's entry points. On the SAU2 the
controller is absent: IIC_$INIT is empty and the eight others are stubs
that report "device not in system" (and IIC_$EXISTS, IIC_$RECEIVE_CHECK
answer false).

## Layout

One module, `iic.pas`, `module iic;` (the map segment's name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| .TEXT | IIC, 0xA0 bytes | the nine IIC_ routines, then the compiled module-end filler | none |

No data: IIC_$NETWORK_UID lies in the UID_LIST segment (another unit's
data, with NIL_ and USER_$NETWORK_UID), and the map's IIC_AQWRD_PROC and
IIC_AQWRD_DATA sections are empty (size 0, four labels at one address).
No routine is nested or module-local; none loads A5.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| IIC_$INIT | `init.pas` (an empty procedure, a bare return) |
| IIC_$ACQUIRE | `acquire.pas` |
| IIC_$RELEASE | `release.pas` |
| IIC_$STATISTICS | `statistics.pas` |
| IIC_$SELF_TEST | `self_test.pas` |
| IIC_$SEND | `send.pas` |
| IIC_$EXISTS | `exists.pas` |
| IIC_$RECEIVE | `receive.pas` |
| IIC_$RECEIVE_CHECK | `receive_check.pas` |

`iic.ins.pas` holds the status and the nine headings: the default
convention, every unread slot `in ... integer32` with placeholder names,
the counts pinteger.

## The conformance unit

`../domain-pascal/tests/conformance/iic.pas` is the whole module,
byte-identical in `make conform`.  The tree's `dpc -o iic/iic.pas`,
assembled, is also byte-identical with the image's 0xA0 bytes (checked
with `m68k-elf-as -m68010` and `cmp`).  The differences, none of which
changes the code:

- the unit declares its own `status_$t` (a record of `all` only); the
  tree uses base/base.ins.pas's (Apollo's packed record, `all` at 0);
- the unit's constant is the same name and value; the tree's is in
  `iic.ins.pas` with its stcode text;
- the unit has no insert file and no `define`; the tree declares the
  headings `extern` in `iic.ins.pas` and `define`s the nine routines;
- IIC_$RECEIVE's counts are `integer` there, `pinteger` here (both a
  word store through the slot);
- the unit groups the unread parameters (`in arg1, arg2: integer32`);
  the tree lists them one by one (the same slots).

## Open items

None.  No TODO, no dpc gap.
