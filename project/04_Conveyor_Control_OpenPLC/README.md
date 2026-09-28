# 04 Conveyor Control (OpenPLC & OIP)

Projek kendali konveyor belt dengan OpenPLC via protokol Modbus TCP (Port 502).

## Menjalankan & Mematikan OpenPLC Runtime (Docker)

Jika OpenPLC Runtime dijalankan melalui container Docker `openplc-runtime`:

### 1. Menyalakan Runtime (Start)
```bash
docker start openplc-runtime
```

### 2. Mematikan Runtime (Stop)
```bash
docker stop openplc-runtime
```

### 3. Memeriksa Status Container
```bash
docker ps -a --filter name=openplc-runtime
```

### 4. Membuka Web Dashboard
- URL: [https://localhost:8443](https://localhost:8443) (atau port default OpenPLC)
- Pastikan status runtime **RUNNING**.

---

## Pemetaan I/O Modbus TCP

| Device | Node Godot | Tag OIP | Alamat OpenPLC | Variabel PLC | Keterangan |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Conveyor 1** | `BeltConveyor` | `co0` | `%QX0.0` | `MOTOR` | Motor konveyor utama |
| **Conveyor 2** | `BeltConveyor2` | `co0` | `%QX0.0` | `MOTOR` | Motor transfer (paralel) |
| **Start Button** | `PushButton_Start` | `co1` | `%QX0.1` | `START` | Tombol NO Start |
| **Stop Button** | `PushButton_Stop` | `co2` | `%QX0.2` | `STOP` | Tombol NC Stop |
| **Emergency** | `PushButton_Stop_Emergency` | `co2` | `%QX0.2` | `STOP` | Tombol Emergency Stop |
| **Sensor Boks** | `DiffuseSensor` | `co3` | `%QX0.3` | `SENSOR` | Deteksi kardus |
| **Counter Trigger**| `Computer` | `co4` | `%QX0.4` | `OBJECT_DETECTION` | Trigger terminal komputer |
| **StackLight Green**| `StackLight` | `co5` | `%QX0.5` | `GREEN_LAMP` | Indikator motor ON |
| **Counter Register**| `Computer` | `hr0` | `%QW0 / Reg 0` | - | Nilai hitungan kardus |

---

## Logika Ladder Diagram (`main.ld`)

```pascal
MOTOR := (MOTOR OR START) AND NOT(STOP);
OBJECT_DETECTION := SENSOR;
GREEN_LAMP := MOTOR;
```
