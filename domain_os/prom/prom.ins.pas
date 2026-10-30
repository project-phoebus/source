{ prom/prom.ins.pas - the boot PROM's cells, for the Domain Pascal tree.

  What the Pascal files use of the PROM's cells.  Include
  base/base.ins.pas before it.
}

type
  { PROM_$MACHINE_ID's two views: the longword ASKNODE_$INTERNET_INFO
    copies, and the word GET_BUILD_TIME reads at the same address (not
    +2): the longword's high half on this big-endian machine, the
    SAU-and-aux code.  No compiled code reads the low half alone.  4
    bytes. }
  prom_$machine_id_t = record
    case integer of
      1: (id: integer32);                 { 0x00 }
      2: (sau: integer);                  { 0x00: the high half }
  end;

var
  { PROM_$MACHINE_ID at 0x100 (map symbol, inside the map's TRAP_PAGE;
    the PROM writes it, the image has no bytes for it).
    ASKNODE_$INTERNET_INFO reads a longword; GET_BUILD_TIME reads the
    word at its address, then tests it and passes it by address to a
    `%wd' (a word): the record above, the longword with a word view.
    Another unit's variable by its absolute address. }
  prom_$machine_id: extern prom_$machine_id_t;
