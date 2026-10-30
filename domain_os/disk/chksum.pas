{ disk/chksum.pas - the CHKSUM module: the checksum of a physical page.

  One compilation unit, one code segment, no data: the map's CHKSUM code
  segment in WIRED_PROC (0x84 bytes; the SAU9's 0x50), the one routine
  CHKSUM and the module-end filler.  CHKSUM_$GET_CHKSUM, the hand assembly it calls, is
  CHKSUM_ASM's (chksum/m68k/get_chksum.s).

  The heading names no sections; the routine is headed
  `[section(wired_proc, wired_data)]' (dma/dma.pas the same).

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/disk/chksum.pas.  Check: tools/pascal_check.sh.
}
module chksum;

%include 'base/base.ins.pas';
%if pft_mmu %then
%include 'mmu/mmu.ins.pas';
%else

{ TODO(pascal) MMU's headings for the other MMU belong in mmu/mmu.ins.pas

  Without the page frame table MMU (`pft_mmu') MMU_$REMOVE takes a
  virtual address and a word (CHKSUM passes CHK_BUFF and 0), where
  mmu/mmu.ins.pas declares the one-argument form its other callers use
  under every configuration.  As os/os.pas does, this module declares
  the MMU headings it uses here and does not include that file, until it
  carries the other form under a part of its own, once every caller has
  its form. }

{ MMU_$INSTALL (hand assembly): the page number and the virtual address,
  longwords, then the ASID and the protection, all by value. }
procedure mmu_$install(ppn: integer32; va: univ_ptr; asid: integer;
                       prot: integer);
  options(extern, val_param);

{ MMU_$REMOVE (hand assembly): a page's mapping removed; the address and
  a word, by value. }
procedure mmu_$remove(va: univ_ptr; flags: integer);
  options(extern, val_param);
%endif
%include 'chksum/chksum.ins.pas';

{ The global routine this module defines (ref 7.3.4, Method 2). }
define
  chksum;

{ ---- WIRED_PROC ---- }
%include 'disk/chksum_page.pas';          { CHKSUM }
