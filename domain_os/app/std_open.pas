{ APP_$STD_OPEN - open the standard application IDP channel.

  Image addresses:
    sau2  0x00E00B92  APP_$STD_OPEN

  - The module's exclusion lock is initialized and socket 16#499 opened
    (XNS_IDP_$OS_OPEN) on the first routing port's network, APP_$DEMUX
    its demux routine; a success records the channel in
    APP_$STD_IDP_CHANNEL.

  Status stored: none.
}

{ TODO(pascal) opt 8-aligned, 4 bytes above it not addressed

  With the two locals declared in this order and allocated downward with
  longword alignment (dpc's model), opt would sit directly below the
  frame's top and status below it; the SAU2 image has 4 unaddressed
  bytes above opt.  The rule that objects of 8 bytes or more lie at
  multiples of 8 gives exactly this: opt, 36 bytes, at the next multiple
  of 8, and status below it.  Either that rule or a 4-byte local first
  (a stand-in) fits; the rule is kept, so no stand-in is declared, and
  dpc's frame differs. }

procedure app_$std_open;
var
  opt: xns_$os_open_opt_t;
  status: status_$t;
begin
  ml_$exclusion_init(exclusion_lock);

  opt.socket := app_std_protocol;
  opt.flags_channel := app_open_flag_bind_local;
  opt.network := route_$portp[0]^.network;
  opt.demux := addr(app_$demux);

  xns_idp_$os_open(opt, status);

  if status.all = status_$ok then
    app_$std_idp_channel := opt.flags_channel;
end;
