PROGRAM main
  VAR
    TimerPusher : TP;
  END_VAR
  VAR
    COLOR_SENSOR AT %QW1 : INT;
    PUSHER AT %QX0.0 : BOOL;
    DO_Conveyor AT %QX0.1 : BOOL;
  END_VAR

  (* Jalur Conveyor selalu aktif *)
  DO_Conveyor := TRUE;

  (* Jika box berwarna merah (COLOR_SENSOR = 1), dorong box dengan mengaktifkan diverter selama 800ms *)
  TimerPusher(IN := (COLOR_SENSOR = 1), PT := T#800ms);
  PUSHER := TimerPusher.Q;

END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#20ms, PRIORITY := 1);
    PROGRAM instance0 WITH task0 : main;
  END_RESOURCE
END_CONFIGURATION

