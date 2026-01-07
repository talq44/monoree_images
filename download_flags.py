# download_flags.py
import argparse
import os
import requests
from tqdm import tqdm

def download_flags():
    """
    Downloads country flags from flagcdn.com based on a list of country codes.
    """
    parser = argparse.ArgumentParser(description="Country Flag Downloader")
    parser.add_argument(
        "--input_file",
        type=str,
        default="countries.txt",
        help="Path to the input text file with a list of ISO 3166-1 alpha-2 country codes."
    )
    parser.add_argument(
        "--output_dir",
        type=str,
        default="flags",
        help="Directory to save the downloaded flag images."
    )
    parser.add_argument(
        "--width",
        type=int,
        default=640,
        help="Width of the flag image to download (e.g., 160, 320, 640)."
    )
    parser.add_argument(
        "--format",
        type=str,
        default="png",
        choices=["png", "svg", "webp"],
        help="Image format to download."
    )
    args = parser.parse_args()

    # --- 1. Initialization ---
    print("--- Initializing Flag Downloader ---")

    # Create output directory if it doesn't exist
    os.makedirs(args.output_dir, exist_ok=True)
    print(f"Output directory: '{args.output_dir}'")

    # Read country codes from the input file
    try:
        with open(args.input_file, 'r') as f:
            country_codes = [line.strip().lower() for line in f if line.strip() and not line.startswith('#')]
        if not country_codes:
            print(f"⚠️ No country codes found in '{args.input_file}'.")
            return
        print(f"Found {len(country_codes)} country codes to download.")
    except FileNotFoundError:
        print(f"❌ Error: Input file not found at '{args.input_file}'")
        return

    # --- 2. Download Loop ---
    print("\n--- Starting Flag Downloads ---")
    base_url = f"https://flagcdn.com/w{args.width}"
    
    for code in tqdm(country_codes, desc="Downloading Flags"):
        output_filename = f"{code}.{args.format}"
        output_filepath = os.path.join(args.output_dir, output_filename)
        
        # Skip if file already exists
        if os.path.exists(output_filepath):
            tqdm.write(f"⚠️ Skipping '{code}': Image already exists.")
            continue
            
        image_url = f"{base_url}/{code}.{args.format}"
        
        try:
            response = requests.get(image_url, stream=True)
            response.raise_for_status()  # Raise an exception for bad status codes (4xx or 5xx)

            with open(output_filepath, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            
            tqdm.write(f"✅ Downloaded: {output_filepath}")

        except requests.exceptions.RequestException as e:
            tqdm.write(f"❌ Error downloading flag for '{code}': {e}")
            continue

    print("\n--- All flag downloads completed! ---")


if __name__ == "__main__":
    download_flags()
