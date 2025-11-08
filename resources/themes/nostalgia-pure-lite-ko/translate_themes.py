
import os
import re
from googleapiclient.discovery import build

# This is a placeholder for the actual translation function.
# In a real scenario, you would use a proper translation API.
def translate_text(text, target_language='ko'):
    """Translates text to the target language."""
    # This is a mock translation.
    # Replace this with a real translation API call.
    if text == "GAME GENRE":
        return "게임 장르"
    # Add more mock translations here for other texts
    return f"[Translated] {text}"

def translate_theme_files():
    """
    Finds all theme.xml files and translates the text within <text> tags.
    """
    for root, dirs, files in os.walk('.'):
        for file in files:
            if file == 'theme.xml':
                filepath = os.path.join(root, file)
                print(f"Processing {filepath}...")
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Find all text to translate
                text_to_translate = re.findall(r'<text>(.*?)</text>', content)

                if not text_to_translate:
                    print("No text found to translate.")
                    continue

                # Create a dictionary for translations
                translations = {}
                for text in set(text_to_translate):
                    # In a real script, you would call a translation API here.
                    # For this example, we'll just use our mock function.
                    translated_text = translate_text(text)
                    translations[text] = translated_text
                    print(f'"{text}" -> "{translated_text}"')


                # Replace the text in the content
                for original, translated in translations.items():
                    content = content.replace(f'<text>{original}</text>', f'<text>{translated}</text>')

                # Write the translated content back to the file
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)

                print("Translation complete.")

if __name__ == '__main__':
    translate_theme_files()
