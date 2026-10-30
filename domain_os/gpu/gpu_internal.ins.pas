{ gpu/gpu_internal.ins.pas - the graphics processor driver's own
  declarations (the hardware, the hand-written GPU_ASM objects, the
  physical page table and the command records), for the Domain Pascal
  tree.

  Only with `gpu_driver' (base/config.ins.pas: the SAU5 and SAU6); only
  gpu/gpu.pas includes this file, after base, ec, ml, time, proc1, fim
  and gpu/gpu.ins.pas.  The records are checked field by field against
  the SAU5 image.
}

%if gpu_driver %then
type
  { The graphics processor's registers (the map's GPU, 16#FF8000 on the
    SAU5, among the I/O definitions): the data port at +0 (the PIO
    writer stores each command word there; reads return the processor's
    answers), the status word at +2 (bit 0 busy, bit 2 an error, bit 5
    ready), and two words the driver only clears, +4 (to stop a command
    that timed out) and +6 (the reset). }
  gpu_regs_t = [device] record
    data: pinteger;                       { 0x00 }
    status: pinteger;                     { 0x02 }
    abort_word: pinteger;                 { 0x04 }
    reset_word: pinteger;                 { 0x06 }
  end;

  { A command to the processor, as the driver builds them in its frame:
    the opcode word, the number of argument words after the count, and
    up to two longword arguments (16#41E0, 4: a page's virtual and
    physical addresses; 16#41E1, 2: a physical address; 16#41C2, 2: a
    register number; 16#41E2 and 16#41E5, 0: none).  The PIO writer
    sends 2 + len words. }
  gpu_cmd_t = record
    op: pinteger;                         { 0x00 }
    len: pinteger;                        { 0x02 }
    arg1: integer32;                      { 0x04 }
    arg2: integer32;                      { 0x08 }
  end;

  { A command with no arguments, 4 bytes (GPU_$TERM's and GPU_$FLUSH's
    16#41E2 command: their frames have only the two words). }
  gpu_cmd0_t = record
    op: pinteger;                         { 0x00 }
    len: pinteger;                        { 0x02 }
  end;

  { GPU_$CMND's command buffer, 32 bytes: one command as above, or the
    sixteen words of its four register writes (below). }
  gpu_cmd_buf_t = record
    case integer of
      0: (cmd: gpu_cmd_t);
      1: (words: array[1..16] of pinteger);
  end;

  { An entry of the physical page table, 12 bytes: the next and previous
    entries' page numbers (a circular list of the pages wired for the
    processor) and the page's virtual address (the high 22 bits) with
    its owner's process number (the low 10 bits); zero when the page is
    not wired. }
  gpu_page_entry_t = record
    next: integer32;                      { 0x00 }
    prev: integer32;                      { 0x04 }
    info: integer32;                      { 0x08 }
  end;

  { The table, indexed by physical page number from 512: every user
    reaches page p at the table's pointer + 12 * p - 0x1800.  GPU_$INIT
    maps it, 0xA800 bytes (3584 entries), from a file of its own. }
  gpu_page_table_t = array[512..4095] of gpu_page_entry_t;
  gpu_page_table_ptr_t = ^gpu_page_table_t;

  { The eventcounts GPU_$CMND waits on (EC_$WAITN's list) and their
    values: the processor's done eventcount, the clock, the process's
    quit eventcount, the page-fault eventcount, COLOR2's interrupt
    eventcount. }
  gpu_wait_ecs_t = array[1..5] of ec_$eventcount_ptr_t;
  gpu_wait_vals_t = array[1..5] of integer32;

const
  { GPU_$CMND's `case' on EC_$WAITN's result: the 1-based number of the
    eventcount that ended the wait, in the list's order (above). }
  gpu_wait_done = 1;
  gpu_wait_clock = 2;
  gpu_wait_quit = 3;
  gpu_wait_page = 4;
  gpu_wait_draw = 5;

var
  { GPU (map symbol among the I/O definitions): the registers. }
  gpu: extern gpu_regs_t;

  { The hand-written GPU_ASM data of the SAU5 (WIRED_DATA, 0x5C bytes;
    gpu/sau5/gpu_asm.s): GPU_$DONE_EC and GPU_$PAGE_EC, eventcounts the
    interrupt handler advances; GPU_$USER_PID, the process that holds the
    processor (0 when none: the driver's lock); GPU_$ML_LOCK, the lock
    over it; and GPU_$PRESENT (gpu/gpu.ins.pas).  The names are the
    map's. }
  gpu_$done_ec: extern ec_$eventcount_t;
  gpu_$page_ec: extern ec_$eventcount_t;
  gpu_$user_pid: extern pinteger;
  gpu_$ml_lock: extern ml_$exclusion_t;

  { COLOR2_$INT_EC, which GPU_$COLD_INIT puts in GPU_$CMND's wait
    list, is color2/color2.ins.pas's. }
%endif
