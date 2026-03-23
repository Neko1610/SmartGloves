# 🖐️ Smart Hand Sign Recognition System (IoT + AI + Sensors)

## 📌 Description

This project is a smart hand sign recognition system that combines computer vision and IoT sensor data.

The system uses:

* YOLOv8 for camera-based hand sign recognition
* ESP32 with flex sensors and MPU6050 to capture hand movement signals

It enables real-time recognition of hand signs using both image and sensor data.

---

## 🚀 Features

* Real-time hand sign recognition using YOLOv8
* Sensor-based gesture detection using flex sensors and MPU6050
* Data acquisition from ESP32 (analog + motion data)
* MQTT communication between devices and server
* Prototype system supporting multiple input methods

---

## 🛠️ Technologies

* Python
* YOLOv8 (Ultralytics)
* OpenCV
* ESP32
* Flex Sensors
* MPU6050 (Accelerometer + Gyroscope)
* MQTT Protocol

---

## ⚙️ System Architecture

1. Camera captures hand image → YOLO detects character
2. Flex sensors + MPU6050 capture hand movement signals
3. ESP32 processes sensor data
4. Data is sent via MQTT to backend
5. System interprets and outputs recognized character

---

## 📂 Project Structure

```id="espfull"
YOLO/
├── train_classify.py
├── detect.py
├── data.py
├── models/
├── sample_images/
├── README.md
```

---

## ▶️ How to Run

### 1. Install dependencies

```id="run1"
pip install ultralytics opencv-python paho-mqtt
```

### 2. Train model

```id="run2"
python train_classify.py
```

### 3. Run detection

```id="run3"
python detect.py
```

---

## 📡 IoT + Sensor Integration

* ESP32 reads data from:

  * Flex sensors (finger bending)
  * MPU6050 (motion & orientation)
* Data is processed and transmitted via MQTT
* System maps sensor values to hand signs

---


## ⚠️ Note

* Dataset and trained weights are not included
* Currently supports limited characters (prototype stage)

---

## 🔮 Future Improvements

* Expand to full A–Z recognition
* Combine sensor + AI for higher accuracy
* Build real-time mobile app (Flutter integration)
* Optimize performance on edge devices

---

## 👨‍💻 Author

Nguyễn Gia Bảo

* GitHub: https://github.com/Neko1610

---
