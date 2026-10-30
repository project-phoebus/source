{ EC2_$INIT - initialize a level-2 eventcount.

  Image addresses:
    sau2  0x00E42C60  EC2_$INIT

  - Only an address above 1000 is cleared: smaller values are EC2
    numbers, not addresses.

  Status stored: none.
}

{ TODO(pascal) four frame bytes of EC2_$INIT, _$READ and _$ADVANCE

  EC2_$INIT and EC2_$ADVANCE each have four frame bytes nothing
  addresses and no local; EC2_$READ's 12 are its two locals and its
  result variable.  A local held in a register, the address, would
  explain the four; the stand-ins unused_4 hold them.  Not settled. }

procedure ec2_$init(out ec: ec2_$eventcount_t);
var
  unused_4: integer32;                    { TODO above }
begin
  if linteger(addr(ec)) > 1000 then begin
    ec.value := 0;
    ec.awaiters := 0;
  end;
end;
