{ color/color.ins.pas - COLOR_ (the color graphics board of the SAU4
  and SAU5 machines) constants, types, variables and routine headings,
  for the Domain Pascal tree.

  The COLOR_ module (color/color.pas) and its hand-written COLOR_ASM
  data (color/sau4/color_asm.s, color/sau5/color_asm.s), with
  `color_board' (base/config.ins.pas).
  No customer insert file declares these.  Include base/base.ins.pas and
  ec/ec.ins.pas before it.

  The board's register pages (COLOR_SUP,
  COLOR_CSTORE) and its display memory (DISP2_MEM) are declared with
  SMD's, which reaches them too (smd/smd_internal.ins.pas
  smd_color_sup_t).
}

%if color_board %then
const
  { The COLOR_ statuses, subsystem 16#26, with the texts of the SR10.2
    status-code database (the names new, from the texts). }
  status_$color_illegal_caller = 16#00260001;       { "illegal caller" }
  status_$color_too_many_wired_pages = 16#00260002;
                                        { "too many wired pages" }
  status_$color_va_not_page_aligned = 16#00260003;
                                        { "virtual address not page aligned
                                          in color_$map" }
  status_$color_pages_unmapped_out_of_order = 16#00260004;
                                        { "pages unmapped out of order" }
  status_$color_iq_done_wait_timed_out = 16#00260007;
                                        { "instruction queue done wait
                                          timed out" }

  { The pages COLOR_$MAP can hold wired (COLOR_$MAP's bound, 33, and the
    size of the module's page list). }
  color_max_pages = 33;

  { The board's command words that turn its display on and off, and its
    interrupt vector (COLOR_$INT_INIT).  With `color_board_iomap' the
    I/O map's entries for the wired pages: COLOR_$MAP's page n goes in
    entry color_iomap_first + n, and COLOR_$UNMAP empties an entry with
    color_iomap_empty. }
%if color_board_iomap %then
  color_cmd_display_on = 16#000E;
  color_cmd_display_off = 16#0006;
  color_int_vector = 16#CE;
  color_iomap_first = 95;
  color_iomap_empty = 16#0FFF;
%else
  color_cmd_display_on = 16#280E;
  color_cmd_display_off = 16#2806;
  color_int_vector = 16#A8;
%endif

  { Where COLOR_$ASSOC puts the board's user page in the caller's address
    space: with `vm_regions' special segment 0's address (MST_$MAP_SPECIAL
    maps the segment there), otherwise the private page at 16#6000. }
%if vm_regions %then
  color_user_va = 16#0F7B8000;
%else
  color_user_va = 16#6000;
%endif

type
  { A cursor's bitmap as COLOR_$LOAD_CRSR reads it: words from the
    first, as many as the cursor's size needs, so a one-element `univ'
    formal (SMD passes its smd_$cursor_bitmap_t, 16 words). }
  color_$cursor_words_t = array[1..1] of pinteger;

var
  { COLOR_$IQ_DONE_EC (map symbol in COLOR_ASM): the eventcount the
    board's "instruction queue done" interrupt advances. }
  color_$iq_done_ec: extern ec_$eventcount_t;

{ ---- COLOR_ASM's routines (hand assembly, color/sau4/color_asm.s,
  color/sau5/color_asm.s). ---- }

{ COLOR_$VECTOR_INIT: defines the board's interrupt; nothing pushed. }
procedure color_$vector_init; extern;

%if not color_board_iomap %then
{ COLOR_$LOAD_MAP: a color map entry's address and its two words, off
  the stack by value (COLOR_$MAP pushes two words and an address,
  COLOR_$UNMAP one longword constant for the two): `val_param'. }
procedure color_$load_map(entry: univ_ptr; word_1: integer;
                          word_2: integer);
  options(extern, val_param);
%endif

{ ---- The module's routines (color/color.pas), in map order. ---- }

{ COLOR_$VIDEO_CTL - turn the color display on or off. }
procedure color_$video_ctl(in flags: boolean); extern;

{ COLOR_$COLD_INIT - initialize the color board's driver at boot. }
procedure color_$cold_init; extern;

{ COLOR_$INT_INIT - set the color board's interrupt registers. }
procedure color_$int_init; extern;

{ COLOR_$ASSOC - give the color board to the calling process. }
procedure color_$assoc(out va: univ_ptr; out cstore: univ_ptr); extern;

{ COLOR_$DISSOC - take the color board back from its owner.
  COLOR_$SHUTDOWN - give up the color board at shutdown. }
procedure color_$dissoc; extern;
procedure color_$shutdown; extern;

{ COLOR_$MAP - wire a buffer's pages and load them into the color map. }
procedure color_$map(in buffer: univ char; in npages: integer;
                     out offset: integer32; out status: status_$t);
  extern;

{ COLOR_$UNMAP - unload and unwire the last pages COLOR_$MAP loaded. }
procedure color_$unmap(in offset: integer32; in npages: integer;
                       out status: status_$t);
  extern;

{ COLOR_$LOAD_CRSR - load a cursor into the color board's memory. }
procedure color_$load_crsr(in cursor_num: integer; in size: integer;
                           in hot_x: integer; in hot_y_adj: integer;
                           in bitmap: univ color_$cursor_words_t);
  extern;

{ COLOR_$INQ_DONE_WAIT - wait for the color board's instruction queue. }
procedure color_$inq_done_wait(out status: status_$t); extern;
%endif
