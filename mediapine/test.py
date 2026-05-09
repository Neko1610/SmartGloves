import cv2
import time
import mediapipe as mp
import joblib
from collections import Counter

# ===== 1. LOAD MODEL =====
try:
    model = joblib.load("model.pkl")
    print("✅ Model loaded!")
except:
    print("⚠️ Không tìm thấy model.pkl, sẽ chỉ chạy test Camera & Mediapipe")
    model = None

# ===== 2. CẤU HÌNH MEDIAPIPE =====
mp_hands = mp.solutions.hands
mp_draw = mp.solutions.drawing_utils
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

# ===== 3. CAMERA BÌNH THƯỜNG =====
cap = cv2.VideoCapture(0)

# Reset các thông số về mặc định để ảnh sáng nhất có thể
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

if not cap.isOpened():
    print("❌ Không mở được Camera")
    exit()

print("🚀 CAMERA NORMAL TEST MODE")
print("Nhấn ESC để thoát.")

buffer_labels = []
last_output = "NONE"
last_time = time.time()

while True:
    ret, frame = cap.read()
    if not ret:
        break

    # Lật ảnh cho tự nhiên (giống soi gương)
    frame = cv2.flip(frame, 1)

    # --- KHÔNG DÙNG GAUSSIAN BLUR HAY CHỈNH ĐỘ SÁNG ÂM ---
    # Giữ nguyên frame gốc để nhìn rõ nhất
    
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    result = hands.process(rgb)

    label = "NONE"

    if result.multi_hand_landmarks:
        hand_landmarks = result.multi_hand_landmarks[0]
        
        # Vẽ landmarks (Xương tay)
        mp_draw.draw_landmarks(
            frame,
            hand_landmarks,
            mp_hands.HAND_CONNECTIONS,
            mp_draw.DrawingSpec(color=(0, 255, 0), thickness=2, circle_radius=3),
            mp_draw.DrawingSpec(color=(0, 0, 255), thickness=2)
        )

        # Dự đoán nếu có model
        if model:
            data = []
            for lm in hand_landmarks.landmark:
                data.append(lm.x)
                data.append(lm.y)
            
            pred = model.predict([data])[0]
            label = str(pred)
            
            if label.upper() != "NONE":
                buffer_labels.append(label)

    # ===== LOGIC HIỂN THỊ KẾT QUẢ =====
    if time.time() - last_time > 0.5: # Cập nhật nhãn mỗi 0.5 giây
        if buffer_labels:
            counter = Counter(buffer_labels)
            final_label, count = counter.most_common(1)[0]
            if count >= 2: # Ít nhất 2 frame giống nhau
                last_output = final_label
        else:
            last_output = "NONE"
        
        buffer_labels = []
        last_time = time.time()

    # ===== UI =====
    # Hiển thị nhãn hiện tại ngay lập tức (Real-time)
    cv2.putText(frame, f"Live: {label}", (20, 40), 
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
    
    # Hiển thị nhãn đã qua lọc (Ổn định)
    cv2.putText(frame, f"RESULT: {last_output}", (20, 80), 
                cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 3)

    cv2.imshow("Normal Camera Test", frame)

    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()