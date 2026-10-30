{ route_$validate_port - whether a network can be reached through a port.

  Image addresses:
    sau2  0x00E65904  route_$validate_port (module-local, ASKNODE)

  - A zero network means port 0, if open, else the answer is 0; another
    network the first open port of it.
  - With no such port the answer is 2 when the question is about this
    node, else 1; with a port, 1 when bit 1 of its driver record's byte
    7 is set, else 2.
  - A fragment of the ASKNODE module (asknode/asknode.pas).

  Status stored: none.
}

{ TODO(pascal) 6 frame bytes of route_$validate_port no object explains

  The reserved slot, i, port, p and the word result come to 18 bytes of
  the frame; the other 6 (the stand-in unused_18 and 2 bytes of
  rounding) are addressed by no instruction. }

function route_$validate_port(routing_key: integer32;
                              is_local: boolean): integer; internal;
type
  driver_head_t = packed record
    unused_00: array[0..6] of char;
    flags_7: boolean;
    flags_6: boolean;
    flags_5: boolean;
    flags_4: boolean;
    flags_3: boolean;
    flags_2: boolean;
    flags_1: boolean;
    flags_0: boolean;
  end;
  driver_head_ptr_t = ^driver_head_t;
var
  i: integer;
  port: route_$port_ptr_t;
  p: route_$port_ptr_t;
  unused_18: integer32;                   { stand-in: the TODO above }
begin
  port := nil;
  if routing_key = 0 then begin
    if route_$portp[0]^.active = 0 then begin
      route_$validate_port := 0;
      return;
    end;
    port := route_$portp[0];
  end else
    for i := 0 to 7 do begin
      p := route_$portp[i];
      if (p^.active <> 0) and then (routing_key = p^.network) then begin
        port := p;
        exit;
      end;
    end;

  if port = nil then begin
    if is_local then
      route_$validate_port := 2
    else
      route_$validate_port := 1;
  end else if not driver_head_ptr_t(port^.driver_info)^.flags_1 then
    route_$validate_port := 2
  else
    route_$validate_port := 1;
end;
