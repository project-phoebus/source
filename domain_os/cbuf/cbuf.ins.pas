{ cbuf/cbuf.ins.pas - CBUF (the circular buffer manager), for the Domain
  Pascal tree.

  What the Pascal files use: the statuses, the buffer's control block
  and the headings.  No customer insert file declares these.  Include
  base/base.ins.pas and ec/ec.ins.pas before it.

  A circular buffer is a caller's array with a control block: blocks
  are allocated at the write end and read and released at the read end.
  A block is a length word followed by the data, its size the length
  plus 2 rounded up to an even number; a zero length word where a block
  would start means the next block is at the buffer's start.  A writer
  that finds no room waits on the control block's eventcount, which a
  release advances.

  The headings are the bodies' (the default convention).
}

const
  { The statuses, from stcode.db.10.2 ("OS / circular buffer
    manager"); CBUF_$ALLOCATE crashes the system with the first, its
    fail bit set (16#801D0001). }
  status_$cbuf_invalid_block_size = 16#001D0001;
                              { invalid block size requested }
  status_$cbuf_invalid_block_size_fail = -16#7FE2FFFF;
  status_$cbuf_quit_while_waiting = 16#001D0002;
                              { quit while waiting }
  status_$cbuf_wrap_around_error = 16#001D0003;
                              { buffer wrap-around error }

type
  { A circular buffer's control block, 0x1C bytes: the buffer's start,
    the read and write ends (addresses, compared unsigned), the
    eventcount a waiting writer waits on, the buffer's size in bytes,
    and whether a writer waits. }
  cbuf_$cb_t = record
    base: linteger;                       { 0x00 }
    read: linteger;                       { 0x04 }
    write: linteger;                      { 0x08 }
    ec: ec_$eventcount_t;                 { 0x0C }
    size: pinteger;                       { 0x18 }
    waiting: boolean;                     { 0x1A }
  end;

  { A block's length word. }
  cbuf_$word_ptr_t = ^pinteger;

  { The buffer, as the caller's array of bytes. }
  cbuf_$buffer_t = array[1..65535] of char;

{ ---- The module's global routines (cbuf/cbuf.pas), in map order. ---- }

{ CBUF_$INIT_CB - set up a circular buffer's control block. }
procedure cbuf_$init_cb(out cb: cbuf_$cb_t; var buf: univ cbuf_$buffer_t;
                        in size: pinteger); extern;

{ CBUF_$ALLOCATE - allocate a block at a circular buffer's write end. }
function cbuf_$allocate(var cb: cbuf_$cb_t; in len: pinteger;
                        out status: status_$t): univ_ptr; extern;

{ CBUF_$MAKE_VISIBLE - make an allocated block readable. }
procedure cbuf_$make_visible(var cb: cbuf_$cb_t; in data: univ_ptr);
  extern;

{ CBUF_$READ_NEXT - the block at a circular buffer's read end. }
function cbuf_$read_next(var cb: cbuf_$cb_t; out len: pinteger): univ_ptr;
  extern;

{ CBUF_$RELEASE - release the block at a circular buffer's read end. }
procedure cbuf_$release(var cb: cbuf_$cb_t); extern;
