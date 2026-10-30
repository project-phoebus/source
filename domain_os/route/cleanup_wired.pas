{ route_$cleanup_wired - unwire the routing area when nothing uses it.

  Image addresses:
    sau2  0x00E69B7C  route_$cleanup_wired (module-local)

  - Only with no user port open and the router not running.

  Status stored: none.
}

procedure route_$cleanup_wired; internal;
var
  i: integer;
begin
  if (route_$n_user_ports = 0) and then not route_$routing then begin
    for i := 1 to route_$n_wired_pages do
      wp_$unwire(route_$wired_pages[i]);
    route_$n_wired_pages := 0;
  end;
end;
