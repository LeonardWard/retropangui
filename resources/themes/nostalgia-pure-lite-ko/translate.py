
import os
import re
import subprocess
import shlex

def translate_text(text):
    """Translates text to Korean using the gemini google-web-search tool."""
    command = f"gemini google-web-search --query \"translate {shlex.quote(text)} to Korean\""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
        output = result.stdout
        # The output is expected to be in the format:
        # Web search results for "translate '...' to Korean":
        #
        # The Korean translation for "..." is "..." (...).
        #
        # Sources:
        # ...
        match = re.search(r'The Korean translation for ".*?" is "(.*?)"', output)
        if match:
            return match.group(1)
        else:
            print(f"Could not find translation for '{text}' in the output.")
            return None
    except subprocess.CalledProcessError as e:
        print(f"Error translating '{text}': {e}")
        return None
    except FileNotFoundError:
        print("Error: The 'gemini' command was not found.")
        print("Please make sure the Gemini CLI is installed and in your PATH.")
        return None

def translate_theme_file(filepath):
    """
    Translates a single theme.xml file.
    """
    print(f"Processing {filepath}...")
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all text to translate
    text_to_translate = re.findall(r'<text>(.*?)</text>', content)

    if not text_to_translate:
        print("No text found to translate.")
        return

    # Create a dictionary for translations
    translations = {}
    for text in set(text_to_translate):
        if re.search('[\uac00-\ud7a3]', text):
            print(f'  Skipping non-ASCII text: "{text}"')
            continue
        translated_text = translate_text(text)
        if translated_text:
            translations[text] = translated_text
            print(f'  \"{text}\" -> \"{translated_text}\"')

    # Replace the text in the content
    for original, translated in translations.items():
        content = content.replace(f'<text>{original}</text>', f'<text>{translated}</text>')

    # Write the translated content back to the file
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print("Translation complete.")

if __name__ == '__main__':
    translate_theme_file("/home/pangui/share/themes/nostalgia-pure-lite/adventure/theme.xml")
