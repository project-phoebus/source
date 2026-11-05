{ iomap/iomap.pas - the IOMAP_ module, the AT bus's I/O map.

  One compilation unit, two code segments and no data: the map's IOMAP_
  code segment in WIRED_PROC (0xB8 bytes: IOMAP_$MAP, IOMAP_$READ,
  IOMAP_$UNMAP) and a second IOMAP_ code segment in OS_INIT_PROC (0x18
  bytes: IOMAP_$INIT).  The map IOMAP_ keeps is IOMAP, the I/O space's
  map of 1024 word entries (pbu/pbu.ins.pas, `word_iomap'); the drivers
  of the AT bus's controllers (WIN7_, FLP_, SCSI_, CT_, RING_8025_, the
  PBU) map their transfers' pages into it.

  The heading names no sections: the module has no variables; every
  routine is headed with the section it lies in.

  Present on the SAUs whose map has the IOMAP_ module, the part
  `iomap_routines' (base/config.ins.pas), empty elsewhere.

  Check: tools/pascal_check.sh.
}
module iomap_;

%include 'base/base.ins.pas';

%if iomap_routines %then
%include 'ec/ec.ins.pas';                 { pbu/pbu.ins.pas needs it }
%include 'pbu/pbu.ins.pas';
%include 'iomap/iomap.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  iomap_$map;
  iomap_$read;
  iomap_$unmap;
  iomap_$init;

{ ---- WIRED_PROC ---- }
%include 'iomap/map.pas';                 { IOMAP_$MAP   }
%include 'iomap/read.pas';                { IOMAP_$READ  }
%include 'iomap/unmap.pas';               { IOMAP_$UNMAP }

{ ---- OS_INIT_PROC ---- }
%include 'iomap/init.pas';                { IOMAP_$INIT  }
%endif
