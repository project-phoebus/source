{ net/net.ins.pas - NET_ (the network device abstraction layer) types
  and routine headings, for the Domain Pascal tree.

  Only what the Pascal files use: the two status codes, the shapes of
  the driver entries NET's dispatchers call, and the six map-global
  headings.  The module is net/net.pas.  No customer insert file
  declares these.  Include base/base.ins.pas before it.
}

const
  { 16#002B0003, "unknown network port" (stcode.db.10.2): stored by
    net_$find_handler. }
  status_$internet_unknown_network_port = 16#002B0003;

  { 16#0011001D, "operation not defined on network hardware"
    (stcode.db.10.2): stored by net_$find_handler and NET_$GET_INFO. }
  status_$network_operation_not_defined_on_hardware = 16#0011001D;

type
  { An argument the dispatchers pass on by address without reading it,
    the formal type of the drivers' `univ' parameters. }
  net_$opaque_t = integer32;

  { The shape of the control entries svc_open, svc_close, svc_ioctl:
    NET_$OPEN passes the port and the two opaque arguments by address
    (its own by-address slots passed on), the fourth a word by value,
    the status by address; 18 bytes and the pad.  A word by value:
    `val_param'.  No result is read (the slot below the arguments is the
    pad). }
  net_$ctl_proc_t = ^procedure(var port: integer;
                               var param3: univ net_$opaque_t;
                               param4: integer;
                               var param5: univ net_$opaque_t;
                               out status: status_$t); options(val_param);

  { The shape of the transfer entries svc_write and svc_read: NET_$RCV
    passes the port, the opaque arguments and the status by address,
    the fourth and seventh words by value; 28 bytes, no pad.
    `val_param' as above. }
  net_$xfer_proc_t = ^procedure(var port: integer;
                                var param3: univ net_$opaque_t;
                                param4: integer;
                                var param5: univ net_$opaque_t;
                                var param6: univ net_$opaque_t;
                                param7: integer;
                                var param8: univ net_$opaque_t;
                                out status: status_$t); options(val_param);

{ Routine headings, in map order (the NET segment, .TEXT).  The bodies
  repeat the full heading (ref 7.3.4, Method 2).  The module-local
  net_$find_handler's heading is in net/net.pas. }

{ NET_$GET_INFO - get information about a network. }
procedure net_$get_info(in net_id: univ net_$opaque_t; in port: univ net_$opaque_t;
                        in param3: univ net_$opaque_t; in param4: univ net_$opaque_t;
                        out status: status_$t); extern;

{ NET_$OPEN - open a network connection.
  NET_$CLOSE - close a network connection.
  NET_$IOCTL - network I/O control. }
procedure net_$open(in net_id: integer; var port: integer;
                    var param3: univ net_$opaque_t; in param4: integer;
                    var param5: univ net_$opaque_t; out status: status_$t);
  extern;
procedure net_$close(in net_id: integer; var port: integer;
                     var param3: univ net_$opaque_t; in param4: integer;
                     var param5: univ net_$opaque_t; out status: status_$t);
  extern;
procedure net_$ioctl(in net_id: integer; var port: integer;
                     var param3: univ net_$opaque_t; in param4: integer;
                     var param5: univ net_$opaque_t; out status: status_$t);
  extern;

{ NET_$RCV - receive on a network connection.
  NET_$SEND - send on a network connection. }
procedure net_$rcv(in net_id: integer; var port: integer;
                   var param3: univ net_$opaque_t; in param4: integer;
                   var param5: univ net_$opaque_t; var param6: univ net_$opaque_t;
                   in param7: integer; var param8: univ net_$opaque_t;
                   out status: status_$t); extern;
procedure net_$send(in net_id: integer; var port: integer;
                    var param3: univ net_$opaque_t; in param4: integer;
                    var param5: univ net_$opaque_t; var param6: univ net_$opaque_t;
                    in param7: integer; var param8: univ net_$opaque_t;
                    out status: status_$t); extern;
