from flask import Flask, request, jsonify
import requests
import os
import tempfile
from tensorflow.keras.models import load_model
import cv2
import numpy as np
from flask_cors import CORS  # Allows requests from Flutter

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter communication

# ImgBB API Key (Replace with your actual API key)
IMGBB_API_KEY = "6df2130389d4a16ff34a749df4d63181"
IMGBB_UPLOAD_URL = "https://api.imgbb.com/1/upload"

# Load the emotion detection model
model_path = r"D:\moviefinal_updated\moviefinal_updated\backend\emotion_model.h5"
if not os.path.exists(model_path):
    raise FileNotFoundError(f"Model file not found: {model_path}")

try:
    model = load_model(model_path)
    print("✅ Model loaded successfully.")
except Exception as e:
    raise RuntimeError(f"❌ Failed to load the model: {str(e)}")

# Emotion labels
EMOTION_LABELS = ["Angry", "Fear", "Happy", "Neutral", "Sad", "Surprise"]

# Function to predict emotion
def predict_emotion(image_path):
    img = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        raise ValueError("❌ Failed to read image. Check the file format and path.")
    
    img = cv2.resize(img, (48, 48))  # Assuming the model expects 48x48 images
    img = np.expand_dims(img, axis=0)
    img = np.expand_dims(img, axis=-1)
    img = img / 255.0  # Normalize
    
    predictions = model.predict(img)
    emotion_index = np.argmax(predictions)  # Get the highest probability index
    
    return EMOTION_LABELS[emotion_index] if emotion_index < len(EMOTION_LABELS) else "Unknown"

@app.route("/")
def home():
    return "✅ Flask server is running! Use /upload to upload images."

@app.route("/upload", methods=["POST"])
def upload_image():
    if "image" not in request.files:
        return jsonify({"error": "❌ No image file provided"}), 400
    
    file = request.files["image"]

    # Save image to a temporary file
    with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as temp_file:
        temp_path = temp_file.name
        file.save(temp_path)

    print("📸 Image saved locally at", temp_path)

    try:
        # Predict emotion
        predicted_emotion = predict_emotion(temp_path)
        print("🧠 Predicted Emotion:", predicted_emotion)

        # Upload image to ImgBB
        with open(temp_path, "rb") as image_file:
            response = requests.post(
                IMGBB_UPLOAD_URL,
                params={"key": IMGBB_API_KEY},
                files={"image": image_file}
            )
            result = response.json()

            if result.get("success"):
                image_url = result["data"]["url"]
            else:
                raise Exception(result.get("error", "Unknown error"))

    except Exception as e:
        print("❌ Error:", str(e))
        os.unlink(temp_path)  # Ensure file is deleted
        return jsonify({"error": "Failed to process image", "details": str(e)}), 500

    os.unlink(temp_path)  # Clean up temp file
    print("🗑️ Image removed locally after processing.")

    return jsonify({"image_url": image_url, "predicted_emotion": predicted_emotion})

if __name__ == "__main__":
    app.run(debug=True)
