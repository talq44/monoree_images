# convert_names_to_codes.py
import pycountry
from tqdm import tqdm

def convert_names_to_codes():
    """
    Converts a list of country names from a file to ISO 3166-1 alpha-2 codes.
    """
    input_file = "flag.txt"
    output_file = "all_country_codes.txt"
    not_found = []

    print(f"--- Converting Country Names from '{input_file}' to Codes ---")

    try:
        with open(input_file, 'r') as f:
            country_names = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print(f"❌ Error: Input file not found at '{input_file}'")
        return

    country_codes = []
    for name in tqdm(country_names, desc="Converting Names"):
        try:
            # search_fuzzy is good at finding countries even with slight name variations
            results = pycountry.countries.search_fuzzy(name)
            if results:
                country_codes.append(results[0].alpha_2.lower())
            else:
                not_found.append(name)
        except Exception as e:
            not_found.append(f"{name} (Error: {e})")

    try:
        with open(output_file, 'w') as f:
            for code in country_codes:
                f.write(f"{code}\n")
        print(f"\n✅ Successfully saved {len(country_codes)} codes to '{output_file}'")
    except IOError as e:
        print(f"❌ Error: Could not write to output file '{output_file}': {e}")

    if not_found:
        print("\n⚠️ The following country names could not be converted to codes:")
        for name in not_found:
            print(f"  - {name}")

if __name__ == "__main__":
    convert_names_to_codes()
