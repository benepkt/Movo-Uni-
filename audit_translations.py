
import json
import re

# Load exercises.json
with open('Movo/Resources/exercises.json', 'r') as f:
    exercises = json.load(f)

# Load LocalizedStrings.swift content
with open('Movo/LocalizedStrings.swift', 'r') as f:
    swift_content = f.read()

# Extract 'de' dictionary range
# Assuming `static let de: [String: String] = [` starts it and we take until `// MARK: - New Exercises (Gym)`? 
# Or just scan until `static let en`.
start_marker = 'static let de: [String: String] = ['
end_marker = 'static let en: [String: String] = ['

start_idx = swift_content.find(start_marker)
end_idx = swift_content.find(end_marker)

de_section = swift_content[start_idx:end_idx]

# Parse key-values from de_section
# Regex for "key": "value"
# Handles simple cases. If multiline or complex escaping, needs care.
key_val_pattern = re.compile(r'"([^"]+)":\s*"([^"]+)"')
de_dict = {}
for match in key_val_pattern.finditer(de_section):
    key, val = match.groups()
    de_dict[key] = val

print(f"Found {len(de_dict)} keys in LocalizedStrings.de")

missing_keys = []
english_values = []

for ex in exercises:
    instr_key = ex.get('instructions', '')
    if instr_key.startswith('exercise.'):
        if instr_key not in de_dict:
            missing_keys.append(instr_key)
        else:
            val = de_dict[instr_key]
            # Check if value looks English (simple heuristic)
            # e.g. "Run on treadmill." vs "Laufe auf dem Laufband."
            # Words "the", "and", "is", "for", "with"
            english_words = ["the", "and", "is", "for", "with", "bench", "press", "squat", "push", "pull"]
            score = 0
            words = val.lower().split()
            for w in words:
                if w in english_words:
                    score += 1
            if score >= 3: # If 3 or more English words
                english_values.append((instr_key, val))

if missing_keys:
    print("MISSING KEYS in DE:")
    for k in missing_keys:
        print(k)
else:
    print("No missing keys found.")

if english_values:
    print("\nPOSSIBLE ENGLISH VALUES in DE:")
    for k, v in english_values:
        print(f"{k}: {v}")
else:
    print("No obvious English values found.")
