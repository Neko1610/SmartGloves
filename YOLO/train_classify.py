from ultralytics import YOLO

def main():

    model = YOLO("yolov8n-cls.pt")

    model.train(
        data="dataset",
        epochs=10,
        imgsz=224,
        device=0,
        project="E:/BanTayThongMinh/YOLO/models",
        name="sign_model"
    )

if __name__ == "__main__":
    main()