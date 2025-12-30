# generator.py
import argparse
import os
import time
import re
import torch
from diffusers import StableDiffusionPipeline
from tqdm import tqdm

def sanitize_filename(name):
    """
    Sanitizes a string to be used as a filename by removing or replacing invalid characters.
    """
    # Replace slashes and backslashes with underscores
    name = re.sub(r'[\\\\/]', '_', name)
    # Remove characters that are problematic in filenames
    name = re.sub(r'[:*?"<>|]', '', name)
    # Trim leading/trailing whitespace and periods
    name = name.strip(' .')
    # Limit length to avoid issues with filesystems
    return name[:200]

def main():
    parser = argparse.ArgumentParser(description="Local AI Image Batch Generator")
    parser.add_argument("--input_file", type=str, required=True, help="Path to the input text file with a list of names.")
    parser.add_argument("--output_dir", type=str, required=True, help="Directory to save the generated images.")
    parser.add_argument("--format", type=str, default="png", choices=["png", "jpeg"], help="Image format for the output.")
    parser.add_argument("--prompt_template", type=str, required=True, help="Prompt template with '{id}' as a placeholder.")
    parser.add_argument("--model_id", type=str, default="runwayml/stable-diffusion-v1-5", help="Hugging Face model ID for the diffusion model.")
    parser.add_argument("--width", type=int, default=512, help="The width in pixels of the generated image.")
    parser.add_argument("--height", type=int, default=512, help="The height in pixels of the generated image.")
    parser.add_argument("--sleep_time", type=int, default=3, help="Cooldown time in seconds between image generations.")
    
    args = parser.parse_args()

    # --- 1. Initialization ---
    print("--- Initializing AI Image Generator ---")
    
    # Check for MPS availability
    if not torch.backends.mps.is_available():
        print("❌ MPS not available. This script requires an Apple Silicon Mac.")
        return

    device = "mps"
    print(f"✅ Using device: {device}")

    # Load the model
    print(f"Loading model '{args.model_id}'... This may take a while.")
    try:
        pipe = StableDiffusionPipeline.from_pretrained(
            args.model_id,
            torch_dtype=torch.float16,
            use_safetensors=True
        )
        pipe = pipe.to(device)
        print("✅ Model loaded successfully.")
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        return

    # Create output directory if it doesn't exist
    os.makedirs(args.output_dir, exist_ok=True)
    print(f"Output directory: '{args.output_dir}'")

    # --- 2. Generation Loop ---
    print("\n--- Starting Image Generation ---")
    
    with open(args.input_file, 'r') as f:
        items = [line.strip() for line in f if line.strip()]

    for item in tqdm(items, desc="Generating Images"):
        output_filename = f"{sanitize_filename(item)}.{args.format}"
        output_filepath = os.path.join(args.output_dir, output_filename)

        # --- Resume Feature ---
        if os.path.exists(output_filepath):
            tqdm.write(f"⚠️ Skipping '{item}': Image already exists.")
            continue

        # --- Prompt Combination ---
        prompt = args.prompt_template.replace("{id}", item)
        tqdm.write(f"Generating image for '{item}' with prompt: '{prompt}'")

        try:
            # --- Inference ---
            with torch.no_grad():
                image = pipe(prompt, width=args.width, height=args.height).images[0]

            # --- NSFW Check (basic) ---
            # The pipeline might return an image that is all black if the NSFW filter is triggered.
            # A more robust check might be needed, but this is a start.
            if image.getbbox() is None:
                 tqdm.write(f"❌ NSFW content detected for '{item}'. Saving a placeholder and skipping.")
                 # Create a black image as a placeholder
                 black_image = Image.new('RGB', (args.width, args.height), color='black')
                 black_image.save(output_filepath)
                 continue

            # --- Save Image ---
            image.save(output_filepath)
            tqdm.write(f"✅ Saved: {output_filepath}")

        except Exception as e:
            tqdm.write(f"❌ Error generating image for '{item}': {e}")
            # Optionally log this to a file
            continue # Continue to the next item

        finally:
            # --- Hardware Protection ---
            tqdm.write(f"Cooldown for {args.sleep_time} seconds...")
            time.sleep(args.sleep_time)

    print("\n--- All tasks completed! ---")

if __name__ == "__main__":
    main()
