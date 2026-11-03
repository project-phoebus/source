{ MST_$UNMAP_ALL - unmap every private A segment of the current address
  space.

  Image addresses:
    sau2  0x00E4483C  MST_$UNMAP_ALL
    sau4  0x0F84CC4A  MST_$UNMAP_ALL
    sau8  0x03C4CDD4  MST_$UNMAP_ALL
    sau9  0x3C44BF5C  MST_$UNMAP_ALL

  - One call of MST_$UNMAP_PRIVI, mode 1, UID_$NIL, from segment 1 for
    MST_$PRIVATE_A_SIZE - 1 segments.

  Status stored:
    MST_$UNMAP_PRIVI's status: in either case
}

procedure mst_$unmap_all(out status_ret: status_$t);
begin
  mst_$unmap_privi(mst_unmap_any_seg, uid_$nil, 16#8000,
                   (mst_$private_a_size - 1) * 16#8000, proc1_$as_id,
                   status_ret);
end;
