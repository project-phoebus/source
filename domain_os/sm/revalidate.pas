{ SM_$REVALIDATE - mark a storage module drive ready again.

  Image addresses:
    sau3  0x00E6E46C  SM_$REVALIDATE
    sau5  0x00E6F7C4  SM_$REVALIDATE

  Status stored: none.
}

procedure sm_$revalidate(in vol: disk_$volume_t);
begin
  sm_$cb.drive[vol.dev_unit].ready := true;
end;
