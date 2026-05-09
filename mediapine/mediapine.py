import cv2
import json
import time
import mediapipe as mp
import joblib
import paho.mqtt.client as mqtt
from collections import Counter

BROKER = "broker.emqx.io"
PORT = 1883

TOPIC_CONTROL = "glove/recognize"
TOPIC_GESTURE = "glove/gesture"

detect_time = 0
detecting = False

#buffer kết quả
buffer_labels = []

# LOAD MODEL
model = joblib.load("model.pkl")

# MEDIAPIPE
mp_hands = mp.solutions.hands
mp_draw = mp.solutions.drawing_utils

hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

# ===== MQTT =====
def on_connect(client, userdata, flags, rc):
    print("MQTT Connected")
    client.subscribe(TOPIC_CONTROL)

def on_message(client, userdata, msg):
    global detect_time, detecting, buffer_labels

    topic = msg.topic
    message = msg.payload.decode()

    print(f"📩 MQTT [{topic}] : {message}")

    if topic == TOPIC_CONTROL and message == "1":
        print("⏳ Detect trong 5 giây...")
        detect_time = time.time() + 5
        detecting = True
        buffer_labels = []

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

client.connect(BROKER, PORT, 60)
client.loop_start()

cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print(" Cannot open camera")
    exit()

print("System ready...")

while True:
    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.flip(frame, 1)

    frame = cv2.convertScaleAbs(frame, alpha=1.2, beta=30)

    now = time.time()
    label = "NONE"

    if detecting:

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        result = hands.process(rgb)

        print("DETECT:", result.multi_hand_landmarks)

        if result.multi_hand_landmarks:
            for hand_landmarks in result.multi_hand_landmarks:

                mp_draw.draw_landmarks(
                    frame,
                    hand_landmarks,
                    mp_hands.HAND_CONNECTIONS,
                    mp_draw.DrawingSpec(color=(0,255,0), thickness=2, circle_radius=4),
                    mp_draw.DrawingSpec(color=(255,0,0), thickness=2)
                )

                data = []
                for lm in hand_landmarks.landmark:
                    data.append(lm.x)
                    data.append(lm.y)

                label = model.predict([data])[0]

                if label != "NONE":
                    buffer_labels.append(label)

    cv2.putText(frame, f"Detect: {label}",
                (20, 50),
                cv2.FONT_HERSHEY_SIMPLEX,
                1,
                (0, 255, 255),
                2)

    if detecting:
        remain = max(0, int(detect_time - now))
        cv2.putText(frame, f"Time: {remain}s",
                    (20, 100),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1,
                    (0, 200, 255),
                    2)

    cv2.imshow("Camera", frame)

    if detecting and now >= detect_time:

        detecting = False

        if buffer_labels:
            counter = Counter(buffer_labels)
            final_label = counter.most_common(1)[0][0]

            if counter[final_label] < 3:
                final_label = "UNKNOWN"
        else:
            final_label = "NONE"

        print(f" FINAL RESULT: {final_label}")
        print(f" BUFFER: {buffer_labels}")

        payload = json.dumps({
            "gesture": final_label,
            "confidence": 1.0
        })

        client.publish(TOPIC_GESTURE, payload)

        buffer_labels = []
        time.sleep(0.3)

    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()
client.loop_stop()
client.disconnect()