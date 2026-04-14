import cv2
import time
import mediapipe as mp
import joblib
from collections import Counter

# ===== LOAD MODEL =====
model = joblib.load("model.pkl")

# ===== MEDIAPIPE =====
mp_hands = mp.solutions.hands
mp_draw = mp.solutions.drawing_utils

hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.6,
    min_tracking_confidence=0.6
)

# ===== CAMERA =====
cap = cv2.VideoCapture(0)

cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
cap.set(cv2.CAP_PROP_EXPOSURE, -6)

if not cap.isOpened():
    print("❌ Cannot open camera")
    exit()

print("🚀 AUTO TEST (ANTI NOISE MODE)")

buffer_labels = []
last_output = "NONE"
last_time = time.time()

while True:
    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.flip(frame, 1)

    frame = cv2.convertScaleAbs(frame, alpha=0.9, beta=-20)

    frame = cv2.GaussianBlur(frame, (5, 5), 0)

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    result = hands.process(rgb)

    label = "NONE"

    if result.multi_hand_landmarks:

        hand_landmarks = result.multi_hand_landmarks[0]

        xs = [lm.x for lm in hand_landmarks.landmark]
        ys = [lm.y for lm in hand_landmarks.landmark]

        w = max(xs) - min(xs)
        h = max(ys) - min(ys)
        cx = sum(xs) / len(xs)

        if w > 0.25 and h > 0.25 and 0.3 < cx < 0.7:

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

            pred = model.predict([data])[0]
            label = pred

            if label != "NONE":
                buffer_labels.append(label)

    # ===== BUFFER LOGIC =====
    if time.time() - last_time > 1:

        if buffer_labels:
            counter = Counter(buffer_labels)
            final_label = counter.most_common(1)[0][0]

            if counter[final_label] < 5:
                final_label = last_output
        else:
            final_label = "NONE"

        if final_label != last_output:
            print("RESULT:", final_label)

        last_output = final_label
        buffer_labels = []
        last_time = time.time()

    # ===== UI =====
    cv2.putText(frame, f"Detect: {last_output}",
                (20, 50),
                cv2.FONT_HERSHEY_SIMPLEX,
                1,
                (0, 255, 255),
                2)

    cv2.imshow("AUTO TEST", frame)

    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()