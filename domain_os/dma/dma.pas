{ dma/dma.pas - the DMA_ module, the MC68450 DMA controller.

  Image addresses:
    sau2  0x00E1E9F0  DMA_ data (WIRED_DATA, 0x4 bytes)

  One compilation unit, one code segment and one data segment: the map's
  DMA_ code segment in WIRED_PROC (0x130 bytes: the module-local
  dma_$init_m68450_channel, DMA_$INIT, DMA_$CHECK, DMA_$FREE_ASID) and
  its DMA_ data segment in WIRED_DATA (4 bytes, zero, which nothing
  addresses: TODO below).

  The heading names no sections: the module has no variables; every
  routine is headed `[section(wired_proc, wired_data)]'.

  Only the SAUs with the controller have the driver (the part
  `dma_driver', base/config.ins.pas); on the others, the SAU5's among
  them, the segment is DMA_$FREE_ASID's 4 bytes.

  Build: dpc -I domain_os domain_os/dma/dma.pas.  Check:
  tools/pascal_check.sh.
}
module dma_;

{ TODO(pascal) the 4-byte WIRED_DATA block that nothing addresses

  The map's 4-byte DMA_ data segment (zero) has no object of the source
  this module can name: no routine has statics or loads A5, and no other
  unit names the block.  As for TAPE_BOOT's OS_INIT_DATA block
  (tape/tape.pas), dpc emits no block for this module. }

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';                 { disk/disk.ins.pas needs it }
%include 'misc/crash_system.ins.pas';
%include 'disk/disk.ins.pas';
%include 'dma/dma.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
%if dma_driver %then
define
  dma_$init;
  dma_$check;
  dma_$free_asid;
%else
define
  dma_$free_asid;
%endif

{ ---- WIRED_PROC ---- }
%if dma_driver %then
%include 'dma/init_m68450_channel.pas';     { dma_$init_m68450_channel }
%include 'dma/init.pas';                    { DMA_$INIT          }
%include 'dma/check.pas';                   { DMA_$CHECK         }
%endif
%include 'dma/free_asid.pas';               { DMA_$FREE_ASID     }
