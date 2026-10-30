{ iic/iic.ins.pas - IIC_ (the internet interface controller), for the
  Domain Pascal tree.

  What the Pascal files use: the status every entry point stores and the
  nine headings.  On the SAU2 the controller is absent: IIC_$INIT is
  empty and the others only report "device not in system".  No customer
  insert file declares these.  Include base/base.ins.pas before it.

  The entry points are reached from the system-call table only (no
  compiled caller in the image), so the headings are the bodies': every
  slot 4 bytes, the default convention (all by address), the status the
  last slot.  The slots the stubs never read have placeholder names and
  integer32, `in' (never written; their real types and modes are not
  visible).
}

const
  { status_$iic_device_not_in_system, 16#002C000A (stcode.db.10.2, "OS /
    internet interface controller": "device not in system"), stored by
    every stub. }
  status_$iic_device_not_in_system = 16#002C000A;

{ IIC_$INIT - initialize the internet interface controller.
  IIC_$ACQUIRE - acquire the internet interface controller.
  IIC_$RELEASE - release the internet interface controller.
  IIC_$STATISTICS - return the internet interface controller's statistics.
  IIC_$SELF_TEST - run the internet interface controller's self test.
  IIC_$SEND - send through the internet interface controller.
  IIC_$EXISTS - whether the internet interface controller is present.
  IIC_$RECEIVE - receive from the internet interface controller.
  IIC_$RECEIVE_CHECK - check the internet interface controller for a
  received message. }
procedure iic_$init; extern;
procedure iic_$acquire(in arg1: integer32; out status: status_$t); extern;
procedure iic_$release(in arg1: integer32; out status: status_$t); extern;
procedure iic_$statistics(in arg1: integer32; in arg2: integer32;
                          out status: status_$t); extern;
procedure iic_$self_test(in arg1: integer32; in arg2: integer32;
                         out status: status_$t); extern;
procedure iic_$send(in arg1: integer32; in arg2: integer32;
                    in arg3: integer32; in arg4: integer32;
                    in arg5: integer32; out status: status_$t); extern;
function iic_$exists: boolean; extern;
procedure iic_$receive(in arg1: integer32; in arg2: integer32;
                       out count_ret3: pinteger; in arg4: integer32;
                       out count_ret5: pinteger; out status: status_$t);
  extern;
function iic_$receive_check(in arg1: integer32;
                            out status: status_$t): boolean; extern;
