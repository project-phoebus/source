{ MST_$DISKLESS_INIT - the diskless node's "partner not responding"
  message, and whether the node has a color display.

  Image addresses:
    sau2  0x00E30DA8  MST_$DISKLESS_INIT
    sau4  0x0F8344B8  MST_$DISKLESS_INIT
    sau6  0x78039B88  MST_$DISKLESS_INIT
    sau7  0x3C4399F4  MST_$DISKLESS_INIT
    sau8  0x03C340CC  MST_$DISKLESS_INIT
    sau9  0x3C436E70  MST_$DISKLESS_INIT

  - The message is formatted once, at boot, into MST_$DISKLESS_MSG with
    this node's ID and its partner's; characters 80..82 become CR, LF,
    CR.  The color flag goes into MST_$GOT_COLOR.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure mst_$diskless_init(color: boolean; mother_node: integer32;
                             my_node: integer32);
var
  len: integer;
begin
  vfmt_$encode2(
    'PARTNER NOT RESPONDING ... RETRYING. CHECK PARTNER.  IF IT HAS CRASHED, REBOOT.xxyMY ID: %5lh  PARTNER: %5lh%%%$',
    mst_$diskless_msg, 121, len, my_node, mother_node);
  mst_$diskless_msg[80] := chr(13);
  mst_$diskless_msg[81] := chr(10);
  mst_$diskless_msg[82] := chr(13);
  mst_$got_color := color;
end;
