{ anon/anon.ins.pas - ANON_ (anonymous objects), for the Domain Pascal
  tree.

  No customer insert file declares this.  Include base/base.ins.pas
  before it.
}

var
  { ANON_$UID (map symbol, among the UID cells after DISPLAY3_$UID and
    OS_WIRED_$UID): the UID of anonymous objects.  pmap_$write_page and
    pmap_$fill_write_qblks read its high longword by its absolute
    address. }
  anon_$uid: extern uid_$t;
