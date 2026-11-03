{ dma/dma.pas - the DMA_ module, the MC68450 DMA controller.

  Image addresses:
    sau2  0x00E1E9F0  DMA_ data (WIRED_DATA, 0x4 bytes)
    sau8  0x03C202E8  DMA_ data (WIRED_DATA, 0x18 bytes)

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

  With the AT bus's DMA channels (`atbus_dma', the SAU8) the driver of
  the bus's two 8237 controllers: the map's DMA_ code segment in
  WIRED_PROC (0x428 bytes: DMA_$START, DMA_$START_NCHECK, DMA_$STOP,
  DMA_$STATUS, DMA_$FREE_ASID), a second DMA_ code segment in
  OS_INIT_PROC (0x98 bytes: the module-local dma_io_delay and
  DMA_$INIT), and the data segment in WIRED_DATA (0x18 bytes):

    +0x00  dma_owner  each channel's address space, dma_free (-1) when
                      free; channel 4, the cascade, 0 (never free)
    +0x10  dma_lock   the spin lock of the owners and the registers
    +0x14  dma_done   the terminal counts seen, a bit per channel
    (the last two bytes are the compiler's padding)

  With them the heading names WIRED_PROC and WIRED_DATA: the routines
  there reach the block through A5, DMA_$INIT by its absolute address.

  Build: dpc -I domain_os domain_os/dma/dma.pas.  Check:
  tools/pascal_check.sh.
}
module dma_, wired_proc, wired_data;

{ TODO(pascal) the 4-byte WIRED_DATA block that nothing addresses

  The map's 4-byte DMA_ data segment (zero) has no object of the source
  this module can name: no routine has statics or loads A5, and no other
  unit names the block.  As for TAPE_BOOT's OS_INIT_DATA block
  (tape/tape.pas), dpc emits no block for this module. }

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';                 { disk/disk.ins.pas needs it }
%include 'misc/crash_system.ins.pas';
%include 'disk/disk.ins.pas';
%if atbus_dma %then
%include 'ml/ml.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'proc1/proc1.ins.pas';
%endif
%include 'dma/dma.ins.pas';

%if atbus_dma %then
var
  dma_owner: array[0..7] of integer := [
    dma_free, dma_free, dma_free, dma_free, 0, dma_free, dma_free,
    dma_free];                            { +0x00 }
  dma_lock: integer32;                    { +0x10 }
  dma_done: integer;                      { +0x14 }
%endif

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
%if atbus_dma %then
define
  dma_$start;
  dma_$start_ncheck;
  dma_$stop;
  dma_$status;
  dma_$free_asid;
  dma_$init;
%elseif dma_driver %then
define
  dma_$init;
  dma_$check;
  dma_$free_asid;
%else
define
  dma_$free_asid;
%endif

{ ---- WIRED_PROC ---- }
%if atbus_dma %then
%include 'dma/start.pas';                   { DMA_$START         }
%include 'dma/start_ncheck.pas';            { DMA_$START_NCHECK  }
%include 'dma/stop.pas';                    { DMA_$STOP          }
%include 'dma/status.pas';                  { DMA_$STATUS        }
%include 'dma/free_asid.pas';               { DMA_$FREE_ASID     }

{ ---- OS_INIT_PROC ---- }
%include 'dma/io_delay.pas';                { dma_io_delay       }
%include 'dma/init.pas';                    { DMA_$INIT          }
%elseif dma_driver %then
%include 'dma/init_m68450_channel.pas';     { dma_$init_m68450_channel }
%include 'dma/init.pas';                    { DMA_$INIT          }
%include 'dma/check.pas';                   { DMA_$CHECK         }
%include 'dma/free_asid.pas';               { DMA_$FREE_ASID     }
%else
%include 'dma/free_asid.pas';               { DMA_$FREE_ASID     }
%endif
