{ gpu/gpu.ins.pas - GPU_ constants and routine headings, for the Domain
  Pascal tree.

  Only what the Pascal files use.  The SAU2 has no graphics processor;
  what is left are the two stubs of the GPU module (gpu/gpu.pas).  The
  GPU_ASM data segment (GPU_$PRESENT, GPU_$PAGE_EC) is hand-written
  data, not this module's (gpu/README.md).  Apollo's customer
  insert files of SR10.2 declare nothing of the GPU.  Include
  base/base.ins.pas before it.

  With `gpu_driver' (base/config.ins.pas: the SAU5 and SAU6) the GPU
  module is the graphics processor's driver; its other global routines'
  headings and the statuses follow, each from the SVC table's argument
  count and the body's reading of the slots.  The driver's own data and
  the hand-written GPU_ASM objects it uses are gpu/gpu_internal.ins.pas.
}

const
  { The graphics processor manager's status; the SR10.2 status-code
    database: "OS / graphics processor manager", "(2d0001) device not
    present in system". }
  status_$gpu_device_not_present = 16#002D0001;

%if gpu_driver %then
  { The driver's other statuses, after the SR10.2 status-code database's
    texts for the numbers ("OS / graphics processor manager"); Apollo's
    insert files have none.  The PIO wait returns 16#2D000A when the
    status word's bit 2 is set (gpu/wait_pio.pas, gpu/wait_pio_timed.pas),
    and
    GPU_$SET_PAGE_LIMITS 16#2D000C for bad limits
    (gpu/set_page_limits.pas). }
  status_$gpu_device_not_available = 16#002D0002;
  status_$gpu_not_initialized = 16#002D0003;
  status_$gpu_already_initialized = 16#002D0004;
  status_$gpu_not_ready_for_pio = 16#002D0005;
  status_$gpu_device_timeout = 16#002D0006;
  status_$gpu_wait_quit = 16#002D0007;
  status_$gpu_error_reported = 16#002D0008;
  status_$gpu_page_fault = 16#002D0009;
  status_$gpu_illegal_page_limits = 16#002D000A;
  status_$gpu_dma_command_error = 16#002D000C;
  status_$gpu_buffer_already_wired = 16#002D000D;
  status_$gpu_buffer_too_large = 16#002D000E;
  status_$gpu_no_microcode = 16#002D000F;
  status_$gpu_draw_processor_error = 16#002D0010;

type
  { A command list for the graphics processor: words, sent one by one to
    its data port (GPU_$CMND passes the caller's list on with its word
    count).  The bound is a placeholder; the length is the count
    argument's. }
  gpu_$words_t = array[1..32767] of pinteger;

  { GPU_$DIAG_WIRE's buffer: pages of 1024 bytes (the body wires page i
    at the buffer's address + 1024 * (i - 1)), at most 256 (its limit);
    and the physical addresses it returns, one longword per page. }
  gpu_$diag_page_t = array[1..1024] of char;
  gpu_$diag_buffer_t = array[1..256] of gpu_$diag_page_t;
  gpu_$page_list_t = array[1..256] of integer32;
%endif

{ GPU_$INIT (gpu/init.pas): user callable, through the SVC table. }
procedure gpu_$init(out status_ret: status_$t); extern;

{ GPU_$TERM (gpu/term.pas): no parameters. }
procedure gpu_$term; extern;

%if gpu_driver %then
{ GPU_$COLD_INIT (OS_INIT_PROC, gpu/cold_init.pas). }
procedure gpu_$cold_init; extern;

{ GPU_$DIAG_ACQUIRE - take the graphics processor for a diagnostic program.
  }
procedure gpu_$diag_acquire(in buf1: univ_ptr; in buf2: univ_ptr;
                            out gpu_va: univ_ptr; out buf1_pa: integer32;
                            out buf2_pa: integer32;
                            out status_ret: status_$t); extern;

{ GPU_$DIAG_RELEASE (gpu/diag_release.pas): a no-argument SVC call. }
procedure gpu_$diag_release; extern;

{ GPU_$FLUSH (gpu/flush.pas): a one-argument SVC call. }
procedure gpu_$flush(out status_ret: status_$t); extern;

{ GPU_$SET_PAGE_LIMITS (gpu/set_page_limits.pas): a three-argument SVC
  call. }
procedure gpu_$set_page_limits(in min_pages: integer; in max_pages: integer;
                               out status_ret: status_$t); extern;

{ GPU_$CMND (gpu/cmnd.pas): a five-argument SVC call. }
procedure gpu_$cmnd(in cmd_list: univ gpu_$words_t; in count: integer;
                    in timeout: integer; out gpu_status: pinteger;
                    out status_ret: status_$t); extern;

{ GPU_$DIAG_WIRE (gpu/diag_wire.pas): a four-argument SVC call. }
procedure gpu_$diag_wire(in buf: univ gpu_$diag_buffer_t; in n_pages: integer;
                         out page_pas: univ gpu_$page_list_t;
                         out status_ret: status_$t); extern;

{ GPU_$INTERRUPT (hand-written, in the GPU's WIRED_DATA code; the map's
  symbol): VME_$INIT stores its address in VME_$INT_VEC's level 4, so
  VME_$INT calls it with the bus's vector, one longword by value, which
  it reads off the stack and compares; it returns a boolean.  The
  handler type's heading (ref p. 4-146). }
function gpu_$interrupt(vector: univ_ptr): boolean;
  options(extern, val_param);
%endif

{ GPU_$PRESENT (map symbol, +0 of the map's GPU_ASM data segment,
  hand-written data): a boolean in the high byte of its word, tested for
  its sign bit by ASKNODE_$INTERNET_INFO.  Another unit's variable by
  its absolute address.  On the SAU5 it is at +0x1A of GPU_ASM, set by
  GPU_$COLD_INIT and tested by GPU_$INIT. }
var
  gpu_$present: extern boolean;
