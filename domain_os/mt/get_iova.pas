{ MT_$GET_IOVA - the I/O address of an object in the MT page.

  Image addresses:
    sau3  0x00E7126A  MT_$GET_IOVA
    sau4  0x0F87DFD6  MT_$GET_IOVA
    sau5  0x00E76DDA  MT_$GET_IOVA
    sau6  0x7807DA76  MT_$GET_IOVA

  - The address is the object's page's entry of MT_$SCB.cfg_iova (one
    for each of the MT page's three pages) with its offset in the page.
    Nothing checks that the object is in the MT page.

  Status stored: none.
}

function mt_$get_iova;
begin
  mt_$get_iova := (integer32(va) & 16#3FF)
                  ! mt_$scb.cfg_iova[rshft(integer32(va)
                                           - integer32(addr(mt_$page_start)),
                                           10) + 1];
end;
