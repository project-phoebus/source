{ OS_$GET_REV_INFO - copy the kernel's revision record to the caller.

  Image addresses:
    sau2  0x00E38030  OS_$GET_REV_INFO

  - A fragment of the PRINT_BUILD_TIME module, whose module file
    (misc/print_build_time_.pas) includes it: its code lies in that
    module's .TEXT segment, and OS_$REV is that module's first object.

  Status stored: none.
}

procedure os_$get_rev_info(out info: os_$rev_t);
begin
  info := os_$rev;
end;
