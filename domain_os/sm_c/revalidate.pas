{ SM_C_$REVALIDATE - revalidate an SM_C volume: nothing to do.

  Image addresses:
    sau3  0x00E6FA76  SM_C_$REVALIDATE
    sau4  0x0F87C7EE  SM_C_$REVALIDATE
    sau5  0x00E755DE  SM_C_$REVALIDATE

  - The SM_C driver keeps no ready flag to set again.

  Status stored: none.
}

procedure sm_c_$revalidate(in vol: disk_$volume_t);
begin
end;
