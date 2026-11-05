{ color2/color2.ins.pas - COLOR2_ (the DN580's and DN570's color
  displays on the graphics board) constants, variables and routine
  headings, for the Domain Pascal tree.

  The COLOR2_ module (color2/color2.pas) and its hand-written
  COLOR2_ASM data (color2/sau5/color2_asm.s), with `gpu_driver'
  (base/config.ins.pas).  No customer insert file declares these.

  Include base/base.ins.pas and ec/ec.ins.pas before it.  The board's
  control block (KOLOR_CTL) and display memories are SMD's declarations
  (smd/smd_internal.ins.pas smd_kolor_ctl_t, smd/smd.ins.pas).
}

%if gpu_driver %then
const
  { "illegal caller" (stcode.db.10.2, the COLOR_ subsystem 16#26):
    COLOR2_$DISSOC's local status for a caller that does not own the
    display. }
  status_$color2_illegal_caller = 16#00260001;

type
  { A cursor's bitmap as COLOR2_$LOAD_CRSR reads it: words from the
    first, as many as the cursor's size needs. }
  color2_$cursor_words_t = array[1..1] of pinteger;

var
  { COLOR2_$INT_EC (map symbol in COLOR2_ASM's hand-written data): the
    eventcount the board's interrupt advances. }
  color2_$int_ec: extern ec_$eventcount_t;
%if gpu_own_vectors %then

  { COLOR2_DONE_VEC (the TRAP_PAGE's map symbol, 16#290: vector 16#A4):
    the board's interrupt vector, which COLOR2_$INT_INIT points at
    COLOR2_$INT_DECODE. }
  color2_done_vec: extern univ_ptr;
%endif

  { COLOR3_$CR_CONTENTS (map symbol in SMD's hand-written SMD_WIRED
    data, smd/m68k/wired_data.s): the copy of the DN570's control word
    (KOLOR_CTL+0x7020, which is only written): bit 3 the video, bit 0
    the reset, set and cleared with word masks. }
  color3_$cr_contents: extern pinteger;

{ COLOR2_$INT_DECODE (hand assembly in COLOR2_ASM): the board's
  interrupt decoder, entered by a jump; only its address. }
procedure color2_$int_decode; extern;

{ ---- The module's routines (color2/color2.pas), in map order. ---- }

{ COLOR2_$VIDEO_CTL - turn the graphics board's color display on or off. }
procedure color2_$video_ctl(in flags: boolean); extern;

{ COLOR2_$COLD_INIT - initialize the graphics board's color display driver
  at boot.
  COLOR2_$INT_INIT - define the graphics board's color interrupt. }
procedure color2_$cold_init; extern;
procedure color2_$int_init; extern;

{ COLOR2_$ASSOC - give the graphics board's color display to the caller. }
procedure color2_$assoc(out ctl: univ_ptr); extern;

{ COLOR2_$DISSOC - take the graphics board's color display back from its
  owner.
  COLOR2_$SHUTDOWN - give up the graphics board's color display at
  shutdown. }
procedure color2_$dissoc; extern;
procedure color2_$shutdown; extern;

{ COLOR2_$LOAD_CRSR - load a cursor into the graphics board's display
  memory. }
procedure color2_$load_crsr(in cursor_num: integer; in size: integer;
                            in hot_x: integer; in hot_y_adj: integer;
                            in bitmap: univ color2_$cursor_words_t);
  extern;

{ COLOR2_$BUSY_WAIT - wait for the graphics board to be idle. }
procedure color2_$busy_wait(out status: status_$t); extern;

{ COLOR2_$GET_EC - the EC2 handle of the graphics board's color interrupt
  eventcount. }
procedure color2_$get_ec(out ec: ec2_$ptr_t; out status: status_$t);
  extern;

{ COLOR2_$ENABLE_GPU_INT - enable the graphics processor's interrupt.
  COLOR2_$DISABLE_GPU_INT - disable the graphics processor's interrupt. }
procedure color2_$enable_gpu_int(out status: status_$t); extern;
procedure color2_$disable_gpu_int(out status: status_$t); extern;
%endif
