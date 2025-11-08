
import os
import re

def find_unique_strings():
    """
    Finds all theme.xml files and collects unique strings from <text> tags.
    """
    unique_strings = set()
    for root, dirs, files in os.walk('.'):
        for file in files:
            if file == 'theme.xml':
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Find all text to translate
                text_to_translate = re.findall(r'<text>(.*?)</text>', content)

                for text in text_to_translate:
                    unique_strings.add(text)

    for string in sorted(list(unique_strings)):
        print(string)

if __name__ == '__main__':
    find_unique_strings()
