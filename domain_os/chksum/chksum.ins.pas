{ chksum/chksum.ins.pas - the page checksum's routines, for the Domain
  Pascal tree.

  The heading of CHKSUM, the compiled CHKSUM module's one routine (its
  body disk/chksum_page.pas, in the module file disk/chksum.pas), and of
  CHKSUM_$GET_CHKSUM, the hand assembly CHKSUM calls
  (chksum/README.md).
}

{ CHKSUM - the checksum of one physical page. }
function chksum(ppn: integer32): pinteger; extern;

%if not pft_mmu %then
var
  { CHK_BUFF (map symbol of the I/O definitions, without `$'): the page
    CHKSUM maps the frame at, 1 KB. }
  chk_buff: extern array[0..511] of pinteger;

%endif

{ CHKSUM_$GET_CHKSUM (hand assembly, chksum/m68k/get_chksum.s): the sum
  of the 512 words of a page, modulo 2^16.  The page's address by value
  off the stack (`val_param'); the sum in D0's word. }
function chksum_$get_chksum(va: univ_ptr): pinteger;
  options(extern, val_param);
