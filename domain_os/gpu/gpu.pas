{ gpu/gpu.pas - the GPU module, the graphics processor manager (no
  graphics processor on the SAU2).

  Image addresses:
    sau5  0x00E8C3B8  GPU data (.DATA, 0x5DC bytes)

  One compilation unit.  On the SAU2 one code segment and no data: the
  map's GPU code segment (section .TEXT, 0x14 bytes) holds GPU_$INIT and
  GPU_$TERM and ends on a longword boundary, so there is no module-end
  filler.  The module is the map segment's name, GPU.

  Not part of the module: the map's GPU_ASM data segment in WIRED_DATA
  (0x10 bytes: GPU_$PRESENT, GPU_$PAGE_EC), the data of a hand-written
  module (the `_ASM' name), which these two routines do not address.
  There is no GPU data segment, so the heading names no section; the
  code is in the default one.

  With `gpu_driver' (base/config.ins.pas; the SAU5 and SAU6 maps' GPU
  segments are the real driver) the module is the graphics processor's
  driver: code in OS_INIT_PROC (0x120 bytes on the SAU5, GPU_$COLD_INIT)
  and .TEXT (0x116C: GPU_$INIT .. GPU_$DIAG_WIRE and eleven module-local
  routines), and the .DATA block below.  Its hand-written GPU_ASM data
  is gpu/sau5/gpu_asm.s.

  The .DATA block, 0x5DC bytes, zero in the SAU5 image; module variables
  in its order:

    +0x000 wired_pages        0x400  GPU_$DIAG_WIRE's pages, from 1
    +0x400 gpu_ec             0xC    the lock's eventcount
    +0x40C unused_40c         4      nothing addresses it (TODO)
    +0x410 page_max           0x80   per process, from 1; > 0 once
                                     GPU_$INIT ran
    +0x490 page_min           0x80   likewise

    +0x510 pages_wired        0x80   likewise: the process's pages in
                                     the page table
    +0x590 wait_vals          0x14   GPU_$CMND's EC_$WAITN values
    +0x5A4 unused_5a4         4      nothing addresses it (TODO)
    +0x5A8 wait_ecs           0x14   its eventcounts
    +0x5BC diag_buf2_pa       4      GPU_$DIAG_ACQUIRE's wired buffers

    +0x5C0 diag_buf1_pa       4
    +0x5C4 page_count         4      the page table's wired entries
    +0x5C8 page_head          4      their list's head
    +0x5CC page_table         4      GPU_$INIT's mapped table
    +0x5D0 diag_wired         2      wired_pages' count

    +0x5D2 context_pid        2      the process whose pages the
                                     processor holds
    +0x5D4 lock_waiters       2      processes waiting for the lock
    +0x5D6 page_faults_ok     1      set by GPU_$COLD_INIT
    +0x5D8 diag_mode          1      GPU_$DIAG_ACQUIRE's mode

  Build: dpc -I domain_os domain_os/gpu/gpu.pas.  Check:
  tools/pascal_check.sh.
}
module gpu;

%include 'base/base.ins.pas';
%if gpu_driver %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'fim/fim.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'mst/mst.ins.pas';
%include 'wp/wp.ins.pas';
%include 'file/file.ins.pas';
%include 'proc2/proc2.ins.pas';
%endif
%include 'gpu/gpu.ins.pas';
%if gpu_driver %then
%include 'color2/color2.ins.pas';
%include 'gpu/gpu_internal.ins.pas';

{ The module's variables (above). }
{ TODO(pascal) bytes of the GPU block nothing addresses (stand-ins unused_40c, unused_5a4)

  No operand of the SAU5 image reaches +0x40C..+0x40F or +0x5A4..+0x5A7.
  Both are what the SMD block's lead (smd/smd.pas: every object of 8
  bytes or more at a multiple of 8) leaves before page_max at +0x410
  and wait_ecs at +0x5A8; dpc aligns static objects to words only. }
var
  wired_pages: array[1..256] of integer32;
  gpu_ec: ec_$eventcount_t;
  unused_40c: integer32;
  page_max: array[1..64] of integer;
  page_min: array[1..64] of integer;
  pages_wired: array[1..64] of integer;
  wait_vals: gpu_wait_vals_t;
  unused_5a4: integer32;
  wait_ecs: gpu_wait_ecs_t;
  diag_buf2_pa: integer32;
  diag_buf1_pa: integer32;
  page_count: integer32;
  page_head: integer32;
  page_table: gpu_page_table_ptr_t;
  diag_wired: integer;
  context_pid: pinteger;
  lock_waiters: integer;
  page_faults_ok: boolean;
  diag_mode: boolean;
%endif

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
%if gpu_driver %then
  gpu_$cold_init;
%endif
  gpu_$init;
  gpu_$term;
%if gpu_driver %then
  gpu_$diag_acquire;
  gpu_$diag_release;
  gpu_$flush;
  gpu_$set_page_limits;
  gpu_$cmnd;
  gpu_$diag_wire;

{ The module-local routines GPU_$COLD_INIT (OS_INIT_PROC) calls before
  their bodies (.TEXT): gpu/pio_write.pas, gpu/reset.pas. }
procedure gpu_$pio_write(in buf: univ gpu_$words_t; count: integer;
                         out done: integer; out gpu_stat: pinteger;
                         out status: status_$t);
  forward; internal;
procedure gpu_$reset;
  forward; internal;

{ ---- OS_INIT_PROC ---- }
%include 'gpu/cold_init.pas';               { GPU_$COLD_INIT }

{ ---- .TEXT ---- }
%include 'gpu/lock.pas';                    { gpu_$lock }
%include 'gpu/unlock.pas';                  { gpu_$unlock }
%include 'gpu/wait_pio.pas';                { gpu_$wait_pio }
%include 'gpu/wait_pio_timed.pas';          { gpu_$wait_pio_timed }
%include 'gpu/pio_write.pas';               { gpu_$pio_write }
%include 'gpu/unwire_page.pas';             { gpu_$unwire_page }
%include 'gpu/unwire_process_pages.pas';    { gpu_$unwire_process_pages }
%include 'gpu/wire_page.pas';               { gpu_$wire_page }
%include 'gpu/service_page_fault.pas';      { gpu_$service_page_fault }
%endif
%include 'gpu/init.pas';                    { GPU_$INIT }
%if gpu_driver %then
%include 'gpu/reset.pas';                   { gpu_$reset }
%include 'gpu/unwire_buffers.pas';          { gpu_$unwire_buffers }
%endif
%include 'gpu/term.pas';                    { GPU_$TERM }
%if gpu_driver %then
%include 'gpu/diag_acquire.pas';            { GPU_$DIAG_ACQUIRE }
%include 'gpu/diag_release.pas';            { GPU_$DIAG_RELEASE }
%include 'gpu/flush.pas';                   { GPU_$FLUSH }
%include 'gpu/set_page_limits.pas';         { GPU_$SET_PAGE_LIMITS }
%include 'gpu/cmnd.pas';                    { GPU_$CMND }
%include 'gpu/diag_wire.pas';               { GPU_$DIAG_WIRE }
%endif
