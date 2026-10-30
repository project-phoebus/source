{ CAL_$WEEKDAY - the day of the week of a date.

  Image addresses:
    sau2  0x00E68670  CAL_$WEEKDAY

  - A Zeller-style congruence, January and February counted in the year
    before; 0 is Sunday.
  - A remainder outside 0..6 (a date before the year 1) takes no arm.

  Status stored: none.
}

function cal_$weekday(in year: integer; in month: integer; in day: integer):
                      cal_$weekday_t;
var
  y: integer;
  sum: integer;
  wd: integer;
begin
  if month >= 3 then
    y := year
  else
    y := year - 1;

  sum := y div 4 + y + 1 - y div 100 + y div 400;
  sum := sum + ((month + 9) mod 12 * 153 + 2) div 5;

  wd := (day + sum + 1) mod 7;

  case wd of
    0: cal_$weekday := cal_$sun;
    1: cal_$weekday := cal_$mon;
    2: cal_$weekday := cal_$tue;
    3: cal_$weekday := cal_$wed;
    4: cal_$weekday := cal_$thu;
    5: cal_$weekday := cal_$fri;
    6: cal_$weekday := cal_$sat;
  end;
end;
