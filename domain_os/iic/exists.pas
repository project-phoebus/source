{ IIC_$EXISTS - whether the internet interface controller is present.

  Image addresses:
    sau2  0x00E70AB0  IIC_$EXISTS

  - The result is always false: the controller is not in the system.

  Status stored: none.
}

function iic_$exists: boolean;
begin
  iic_$exists := false;
end;
