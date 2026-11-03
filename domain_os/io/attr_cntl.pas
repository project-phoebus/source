{ IO_$ATTR_CNTL - set an acquired unit's attributes, returning the old.

  Image addresses:
    sau3  0x00E19A72  IO_$ATTR_CNTL
    sau5  0x00E1AD22  IO_$ATTR_CNTL

  - The slot's attributes go into old_attrs and are replaced by
    new_attrs (IO_$ALLOC_MAP reads io_$attr_wide_iomap).  With the PBU
    only.

  Status stored:
    io_$check_unit's status: always
}

procedure io_$attr_cntl(unit: io_$unit_num_t; new_attrs: io_$attr_t;
                        out old_attrs: io_$attr_t;
                        out status: status_$t);
  options(val_param);
begin
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do begin
      old_attrs := attrs;
      attrs := new_attrs;
    end;
end;
