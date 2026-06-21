
import json
import re
import os

localized_strings_path = "Movo/LocalizedStrings.swift"
exercises_json_path = "Movo/Resources/exercises.json"

def parse_german_strings(path):
    print(f"Reading {path}...")
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Find the German dictionary
    # It starts with 'static let de: [String: String] = [' and ends with ']'
    # We need to capture the content inside the brackets carefully.
    # Since it might be nested or simply long, regex for `static let de ... \[` to first `\]` at root level is tricky 
    # without a parser, but let's try a robust regex like before.
    pattern = r'static let de: \[String: String\] = \[(.*?)\]'
    match = re.search(pattern, content, re.DOTALL)
    
    translations = {}
    if match:
        dict_content = match.group(1)
        # Parse each line: "key": "value",
        kv_pattern = r'"([^"]+)"\s*:\s*"((?:[^"\\]|\\.)*)"'
        for kv_match in re.finditer(kv_pattern, dict_content):
            key = kv_match.group(1)
            value = kv_match.group(2)
            # Unescape value
            value = value.replace('\\"', '"').replace('\\n', '\n')
            translations[key] = value
            
        print(f"Found {len(translations)} German translations.")
    else:
        print("Could not find 'static let de' dictionary!")
    
    return translations

def recover_missing_instructions(json_path, translations):
    print(f"Reading {json_path}...")
    with open(json_path, "r", encoding="utf-8") as f:
        exercises = json.load(f)
    
    recovered_count = 0
    
    for ex in exercises:
        # Check if instructions are empty
        if not ex.get("instructions") or ex["instructions"].strip() == "":
            # Construct the key that WOULD have been used
            # Logic from ExerciseInfo extension: "exercise.instructions." + name_key
            # BUT wait, the name in json is now "Bench Press (Barbell)" (English).
            # We need to find the KEY that corresponds to this exercise.
            # OR we can just look up by the name if we had a reverse map?
            # 
            # Actually, the user's previous `exercises.json` had keys like "exercise.bench_press_barbell".
            # I reverted the NAME to "Bench Press (Barbell)".
            # But I don't easily know the key anymore unless I re-derive it.
            # 
            # Fortunately, I have `revert_exercises.py`'s map!
            # Let's include that map again to REVERSE lookup: Name -> Key.
            pass

    return exercises

# ... (I'll write the full script in the next step, this was deciding logic)
