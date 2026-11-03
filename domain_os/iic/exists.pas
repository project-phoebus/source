{ IIC_$EXISTS - whether a line of the internet interface controller is
  present.

  Image addresses:
    sau2  0x00E70AB0  IIC_$EXISTS
    sau3  0x00E1C738  IIC_$EXISTS

  - Without the driver the result is always false: the controller is not
    in the system.
  - With it, a line in use is present; otherwise the line's control
    register is probed.  The PBU unit is set up for the probe if the
    driver has not set it up, and set down after it.
  - The probe's setup passes the first longword of IIC_$INT's code as
    the handler, not its address; the unit is set down again before an
    interrupt can use it.

  Status stored: none.
}

%if iic_driver %then
[section(wired_proc, wired_data)]
%endif
function iic_$exists(in line: pinteger): boolean;
%if iic_driver %then
type
  iic_code_ptr_t = ^univ_ptr;
var
  status: status_$t;
  data: integer;
%endif
begin
%if iic_driver %then
  if iic_lines[line].state <> iic_line_free then
    iic_$exists := true
  else begin
    if not iic_pbu_acquired then
      pbu_$acquire_int(iic_pbu_unit, iic_code_ptr_t(addr(iic_$int))^, nil,
                       addr(pbu_iic_page), 16#6400, 1, iic_pbu_sharing,
                       status);
    iic_$exists := testpage(0, addr(pbu_iic_page[line]), data);
    if not iic_pbu_acquired then
      pbu_$release_int(iic_pbu_unit, iic_pbu_sharing, status);
  end;
%else
  iic_$exists := false;
%endif
end;
