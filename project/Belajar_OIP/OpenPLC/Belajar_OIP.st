PROGRAM main
  VAR
    DI_SensorPresence AT %IX0.0 : BOOL;
    DI_SensorHeight   AT %IX0.1 : BOOL;
    DO_ConveyorMain   AT %QX0.0 : BOOL;
    DO_ConveyorDivert AT %QX0.1 : BOOL;
    DO_Pusher         AT %QX0.2 : BOOL;
    
    TimerPusher : TP;
  END_VAR

  (* Jalur conveyor default selalu aktif *)
  DO_ConveyorMain := TRUE;
  DO_ConveyorDivert := TRUE;

  (* Pusher menyembur selama 0.8 detik jika box tinggi terdeteksi *)
  TimerPusher(IN := (DI_SensorPresence AND DI_SensorHeight), PT := T#800ms);
  DO_Pusher := TimerPusher.Q;

END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK Task0(INTERVAL := T#20ms, PRIORITY := 0);
    PROGRAM Inst0 WITH Task0 : main;
  END_RESOURCE
END_CONFIGURATION

