{ DXM_$INIT - set up the two DXM queues' eventcounts.

  Image addresses:
    sau2  0x00E2FF50  DXM_$INIT

  - DXM_$WIRED_Q's eventcount, then DXM_$UNWIRED_Q's; the rest of each
    queue record is the image's initial value.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure dxm_$init;
begin
  ec_$init(dxm_$wired_q.ec);
  ec_$init(dxm_$unwired_q.ec);
end;
