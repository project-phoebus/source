{ iomap/iomap.ins.pas - IOMAP_ (the AT bus's I/O map) routine headings,
  for the Domain Pascal tree.

  The IOMAP_ module (iomap/iomap.pas: IOMAP_$MAP, IOMAP_$READ and
  IOMAP_$UNMAP in WIRED_PROC, IOMAP_$INIT in OS_INIT_PROC) keeps the AT
  bus's I/O map, IOMAP (pbu/pbu.ins.pas, with `word_iomap'): a word per
  1 KB page of bus address, the page number of the memory page the bus
  page reaches, 0 when it reaches none.  Include base/base.ins.pas
  before it.
}

type
  { A list of page numbers IOMAP_$MAP takes, of the caller's length
    (`univ'): the low word of each is the entry stored. }
  iomap_$ppn_list_t = array[1..1] of integer32;

{ IOMAP_$MAP - map count pages from the bus address iova: entry i of
  the run gets the low word of ppns[i].  The bus number, the address,
  the count and the flags word by value (`val_param'); the page list and
  the fourth argument (which the routine does not read) by address.
  The status is cleared. }
procedure iomap_$map(bus: integer; iova: integer32;
                     in ppns: univ iomap_$ppn_list_t;
                     in vas: univ iomap_$ppn_list_t;
                     count: integer; flags: integer;
                     out status: status_$t);
  options(extern, val_param);

{ IOMAP_$READ - the map's entry for the bus address iova, the page
  number widened.  Both by value (`val_param'); the bus number is not
  read.  Nothing in the kernel calls it. }
function iomap_$read(bus: integer; iova: integer32): integer32;
  options(extern, val_param);

{ IOMAP_$UNMAP - clear count entries of the map from the bus address
  iova.  All by value (`val_param'); the bus number is not read. }
procedure iomap_$unmap(bus: integer; iova: integer32; count: integer);
  options(extern, val_param);

{ IOMAP_$INIT - clear the map's 1024 entries.  Nothing in the kernel
  calls it. }
procedure iomap_$init;
  extern;
