{ netbuf/netbuf.ins.pas - NETBUF_ (network buffers), for the Domain
  Pascal tree.

  Only what the Pascal files use.  Include base/base.ins.pas and
  pkt/pkt.ins.pas before it.
}

{ NETBUF_$GETVA - map a physical page into a free slot of the window. }
procedure netbuf_$getva(ppn_shifted: integer32;
                        out va_out: univ integer32;
                        out status: status_$t);
  options(extern, val_param);

{ NETBUF_$RTNVA - give back a buffer page's slot of the window. }
function netbuf_$rtnva(in va: univ integer32): integer32; extern;

{ NETBUF_$RTN_HDR - put a header page back on the free list. }
procedure netbuf_$rtn_hdr(in va: integer32); extern;

type
  { A header buffer's page, 0x400 bytes.  The two words a queued packet
    carries, at 0x3E0, 0x3E2: APP_$RECEIVE reads them from the page
    of the packet's header, the second widened with zeros to a longword:
    pinteger.  The queue fields SOCK_$PUT_INT_INT writes and SOCK_$GET
    reads.  dst_port holds the packet record's
    flags (a word set, copied both ways, so a set of 0..15, assignment
    compatible with sock_$pkt_flags_t); data_len and hdr_len two words,
    copied as one longword; hops ten words, up to
    ec_param1; next the queue's link; data_ptrs the data pages, 1-based
    as pkt_$data_pages_t.  The longword at 0x3FC is the page's physical
    address: NETBUF_$ADD_PAGES stores the page's number shifted to an
    address there, NETBUF_$GET_HDR the address it returns, and
    NETBUF_$GET_HDR_COND returns it. }
  netbuf_$hdr_page_t = record
    unused_000: array[0..16#3B7] of char; { 0x000 }
    hdr_ptr: integer32;                   { 0x3B8 }
    src_addr: integer32;                  { 0x3BC }
    src_port: integer;                    { 0x3C0 }
    unused_3c2: integer;                  { 0x3C2 }
    dst_addr: integer32;                  { 0x3C4 }
    dst_port: set of 0..15;               { 0x3C8 }
    hop_count: integer;                   { 0x3CA }
    hops: array[0..9] of integer;         { 0x3CC }
    ec_param1: integer;                   { 0x3E0 }
    ec_param2: pinteger;                  { 0x3E2 }
    next: integer32;                      { 0x3E4 }
    data_len: pinteger;                   { 0x3E8 }
    hdr_len: pinteger;                    { 0x3EA }
    data_ptrs: pkt_$data_pages_t;         { 0x3EC }
    phys: integer32;                      { 0x3FC: the page's physical
                                            address }
  end;
  netbuf_$hdr_page_ptr_t = ^netbuf_$hdr_page_t;

{ NETBUF_$RTN_PKT - give back a packet's header page, window slot and
  data pages. }
procedure netbuf_$rtn_pkt(var hdr: integer32; var va: integer32;
                          in dat_arr: pkt_$data_pages_t; dat_len: integer);
  options(extern, val_param);

{ NETBUF_$ADD_PAGES - grow the header and data page pools.
  NETBUF_$DEL_PAGES - shrink the header and data page pools. }
procedure netbuf_$add_pages(hdr_pages: integer; data_pages: integer);
  options(extern, val_param);
procedure netbuf_$del_pages(hdr_pages: integer; data_pages: integer);
  options(extern, val_param);

{ NETBUF_$GET_HDR_COND - take a header page from the free list, if any. }
function netbuf_$get_hdr_cond(out phys: integer32; out va: integer32):
  boolean; extern;

{ NETBUF_$GET_HDR - take a header page, waiting or allocating one. }
procedure netbuf_$get_hdr(out phys: integer32; out va: integer32); extern;

{ NETBUF_$GET_DAT_COND - take a data page from the free list, if any. }
function netbuf_$get_dat_cond(out addr: integer32): boolean; extern;

{ NETBUF_$GET_DAT - take a data page, waiting or allocating one. }
procedure netbuf_$get_dat(out addr: integer32); extern;

{ NETBUF_$RTN_DAT - give back a data page. }
procedure netbuf_$rtn_dat(addr: integer32); options(extern, val_param);

{ NETBUF_$INIT - set up the network buffers. }
procedure netbuf_$init; extern;

var
  { The map's symbols inside NETBUF_'s data segment (WIRED_DATA),
    defined by netbuf/netbuf.pas, which gives each one's evidence.  RING
    reads two of them by their addresses (DAT_CNT and HDR_TOP). }
  netbuf_$dat_allocs: extern integer32;   { +0x30C }
  netbuf_$hdr_allocs: extern integer32;   { +0x310 }
  netbuf_$dat_delays: extern integer32;   { +0x314 }
  netbuf_$hdr_delays: extern integer32;   { +0x318 }
  netbuf_$dat_lim: extern linteger;       { +0x31C }
  netbuf_$dat_cnt: extern linteger;       { +0x320 }
  netbuf_$dat_top: extern integer32;      { +0x324 }
  netbuf_$hdr_top: extern integer32;      { +0x328 }
  netbuf_hdr_alloc: extern integer;       { +0x334 }
