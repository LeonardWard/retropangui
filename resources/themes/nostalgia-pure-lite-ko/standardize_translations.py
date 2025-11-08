import os
import re
import glob

def standardize_description(desc):
    """
    Applies a set of standardization rules to a theme's short description text
    by rebuilding it from components.
    """
    # Find the year and the bit number
    year_match = re.search(r'(\d{4})', desc)
    bit_match = re.search(r'(\d+)\s*(-?비트)', desc)

    if year_match and bit_match:
        year = year_match.group(1)
        bits = bit_match.group(1)
        
        # Reconstruct the string according to the standard format
        return f"{year} · {bits}비트 게임기"
    
    # If the pattern isn't found, return the original description
    # to avoid breaking other descriptions like "GAME GENRE"
    return desc

def process_theme_files():
    """
    Finds all theme.xml files and standardizes the <shortdescription> text.
    """
    # Use glob to find all theme.xml files recursively
    theme_files = glob.glob('**/theme.xml', recursive=True)
    
    if not theme_files:
        print("No theme.xml files found.")
        return

    print(f"Found {len(theme_files)} theme.xml files to process.")

    # Regex to find the content of the <text> tag within <shortdescription>
    pattern = re.compile(r'(<text name="shortdescription" extra="true">\s*<text>)(.*?)(</text>)', re.DOTALL)

    for filepath in theme_files:
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            original_content = content
            
            # Use a function with re.sub to apply changes
            def replacement_func(match):
                # Extract the parts: prefix, description, suffix
                prefix, description, suffix = match.groups()
                
                # Standardize the description
                standardized_desc = standardize_description(description)
                
                # Return the reconstructed string
                return f"{prefix}{standardized_desc}{suffix}"

            # Apply the replacement
            content, num_replacements = pattern.subn(replacement_func, content)

            # Write back to the file only if changes were made
            if num_replacements > 0:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Standardized: {filepath}")

        except Exception as e:
            print(f"Error processing {filepath}: {e}")

if __name__ == '__main__':
    process_theme_files()
    print("\nStandardization complete.")
