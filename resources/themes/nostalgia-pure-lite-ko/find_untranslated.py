
import os
import re

def find_untranslated_files():
    """
    Finds all theme.xml files and checks for English text within <text> tags.
    """
    for root, dirs, files in os.walk('.'):
        for file in files:
            if file == 'theme.xml':
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Find all text to translate
                text_to_check = re.findall(r'<text>(.*?)</text>', content)

                is_translated = True
                for text in text_to_check:
                    if re.search(r'[a-zA-Z]', text):
                        is_translated = False
                        break
                
                if not is_translated:
                    print(filepath)

if __name__ == '__main__':
    find_untranslated_files()
