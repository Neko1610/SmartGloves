import cv2
import json
import time
from ultralytics import YOLO
import paho.mqtt.client as mqtt

# ================= MQTT CONFIG =================
BROKER = "broker.emqx.io"
PORT = 1883

TOPIC_CONTROL = "glove/recognize"
TOPIC_GESTURE = "glove/gesture"

# ================= STATE =================
detect_time = 0   # thời điểm sẽ detect

# ================= LOAD MODEL =================
model = YOLO("E:/BanTayThongMinh/YOLO/models/sign_model/weights/best.pt")

# ================= MQTT =================
def on_connect(client, userdata, flags, rc):
    print("✅ MQTT Connected")
    client.subscribe(TOPIC_CONTROL)

def on_message(client, userdata, msg):
    global detect_time

    topic = msg.topic
    message = msg.payload.decode()

    print(f"📩 MQTT [{topic}] : {message}")

    if topic == TOPIC_CONTROL and message == "1":
        print("⏳ Đợi 5 giây để đưa tay...")
        detect_time = time.time() + 5  # 🔥 delay 10s

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

client.connect(BROKER, PORT, 60)
client.loop_start()

# ================= CAMERA =================
cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("❌ Cannot open camera")
    exit()

print("🚀 System ready...")

# ================= MAIN LOOP =================
while True:
    ret, frame = cap.read()
    if not ret:
        break

    cv2.imshow("Camera", frame)

    now = time.time()

    # 🔥 ĐẾN GIỜ DETECT
    if detect_time != 0 and now >= detect_time:

        print("🔍 Detecting...")

        results = model(frame)

        probs = results[0].probs.data
        top1 = probs.argmax()
        conf = float(probs[top1])

        label = model.names[int(top1)]

        # threshold
        if conf < 0.6:
            label = "NONE"

        print(f"👉 Result: {label} ({conf:.2f})")

        # gửi JSON về Flutter
        payload = json.dumps({
            "gesture": label,
            "confidence": round(conf, 2)
        })

        client.publish(TOPIC_GESTURE, payload)

        # reset
        detect_time = 0

        time.sleep(0.3)

    # ❌ ESC để thoát
    if cv2.waitKey(1) & 0xFF == 27:
        break

# ================= CLEAN =================
cap.release()
cv2.destroyAllWindows()
client.loop_stop()
client.disconnect()