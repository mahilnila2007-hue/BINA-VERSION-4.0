import os
import shutil
from ultralytics import YOLO

def main():
    print("Loading YOLOv8n-pose...")
    model = YOLO("yolov8n-pose.pt")
    print("Exporting model to TFLite (imgsz=320)...")
    exported = model.export(format="tflite", imgsz=320)
    print("Export result:", exported)

    target_dir = os.path.join("assets", "models")
    os.makedirs(target_dir, exist_ok=True)
    target_file = os.path.join(target_dir, "yolov8n-pose.tflite")

    if exported and os.path.isfile(exported):
        shutil.copyfile(exported, target_file)
        print("Copied file directly to:", target_file)
    elif exported and os.path.isdir(exported):
        for fname in os.listdir(exported):
            if fname.endswith(".tflite"):
                shutil.copyfile(os.path.join(exported, fname), target_file)
                print("Copied", fname, "to", target_file)
                break
    
    if os.path.exists(target_file):
        print(f"SUCCESS: {target_file} created with size {os.path.getsize(target_file)} bytes")
    else:
        print("ERROR: Model file not generated at target")

if __name__ == "__main__":
    main()
