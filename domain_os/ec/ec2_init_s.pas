{ EC2_$INIT_S - initialize the EC2 module at boot.

  Image addresses:
    sau2  0x00E30970  EC2_$INIT_S

  - The 64 per-process wait eventcounts are initialized and the 225
    waiter records chained into the free list from record 1; slot 1
    becomes the always-ready eventcount, and both PBU-pool sets empty.
  - Record 224's next is cleared, ending the free list with 0, which
    EC2_$WAIT reads as "internal table exhausted"; left at 225, it would
    point one past the table.
  - The module's .DATA block is reached by its address (as
    MAC_OS_$INIT).

  Status stored: none.
}

{ TODO(pascal) four frame bytes of EC2_$INIT_S hold nothing

  The two loop indices make 4 of the frame's 8 bytes; the stand-in
  unused_8 holds the other four.  A longword index would explain it,
  but the image's j is a word.  Not settled. }

[section(os_init_proc, os_init_data)]
procedure ec2_$init_s;
var
  i: integer;
  j: integer;
  unused_8: integer32;                    { TODO above }
begin
  { the per-process eventcounts }
  for i := 1 to 64 do
    ec_$init(ec2_$wait_ecs[i]);

  { the waiter records }
  for j := 0 to 224 do begin
    ec2_waiter_table_base[j].proc_id := 0;
    ec2_waiter_table_base[j].wait_val := 0;
    ec2_waiter_table_base[j].next := j + 1;
  end;

  { the cells }
  ec2_waiter_table_base[224].next := 0;
  ec2_$free_head := 1;
  ec2_$max_registered := 1;
  ec2_$registered_ec1s[ec2_$always_ready_ec] := addr(ec2_$max_registered);
  ec2_$pbu_allocated := [];
  ec2_$pbu_pending := [];
end;
