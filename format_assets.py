import os
from PIL import Image

# --- Configuration ---
CANVAS_SIZE = 512
INPUT_DIR = "D:/repos/gamedev/test"
OUTPUT_DIR = "D:/repos/gamedev/godot_client/assets/items"

# --- Alignment Rules ---
# target_width: How wide the item should be in pixels.
# y_offset: How many pixels down from the top (0) the item should be placed.
# You will likely need to tweak these numbers slightly based on your specific AI generations!
ALIGNMENT_RULES = {
    "body":   {"target_width": 160, "y_offset": 120},  # Centered, lower down
    "hair":   {"target_width": 180, "y_offset": 100},  # Slightly wider than body, sits on head
    "hat":    {"target_width": 160, "y_offset": 40},   # Sits near the top of the canvas
    "outfit": {"target_width": 190, "y_offset": 230},  # Sits lower down on the torso
    "back":   {"target_width": 280, "y_offset": 110},  # Wide (like wings), sits behind
    "default":{"target_width": 150, "y_offset": 150}
}

def process_image(input_path, output_path, category):
    try:
        # 1. Open the image and ensure it has an Alpha (transparency) channel
        img = Image.open(input_path).convert("RGBA")

        # 2. Find the bounding box of non-transparent pixels and crop away empty space
        bbox = img.getbbox()
        if not bbox:
            print(f"Skipping {os.path.basename(input_path)} (Image is completely empty)")
            return
            
        cropped = img.crop(bbox)

        # 3. Calculate new size while maintaining perfect aspect ratio
        rules = ALIGNMENT_RULES.get(category, ALIGNMENT_RULES["default"])
        target_w = rules["target_width"]
        
        ratio = target_w / float(cropped.size[0])
        target_h = int(float(cropped.size[1]) * float(ratio))
        
        # Resize using Lanczos for the highest quality downscaling
        resized = cropped.resize((target_w, target_h), Image.Resampling.LANCZOS)

        # 4. Create a blank 512x512 transparent canvas
        canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))

        # 5. Calculate X (centered horizontally) and Y (from your rules)
        paste_x = (CANVAS_SIZE - target_w) // 2
        paste_y = rules["y_offset"]

        # 6. Paste the item onto the canvas (using itself as the transparency mask)
        canvas.paste(resized, (paste_x, paste_y), resized)

        # 7. Save the final Godot-ready asset
        canvas.save(output_path, "PNG")
        print(f"✅ Processed: {category}/{os.path.basename(output_path)}")

    except Exception as e:
        print(f"❌ Error processing {input_path}: {e}")

def main():
    # Ensure output directory exists
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    # Walk through the raw_assets directory
    for root, dirs, files in os.walk(INPUT_DIR):
        for file in files:
            if file.lower().endswith(".png"):
                input_path = os.path.join(root, file)
                
                # Determine category by folder name (e.g., 'hat', 'hair')
                category = os.path.basename(root).lower()
                
                # Create corresponding output subdirectory
                cat_out_dir = os.path.join(OUTPUT_DIR, category)
                if not os.path.exists(cat_out_dir):
                    os.makedirs(cat_out_dir)
                    
                output_path = os.path.join(cat_out_dir, file)
                
                process_image(input_path, output_path, category)

if __name__ == "__main__":
    print("Starting Avatar Asset processing...")
    main()
    print("Done! Check your 'assets/items/' folder.")