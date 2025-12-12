#!/usr/bin/env python3
import sys
import json

# Number of bars should match cava config
bars = 12

def main():
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        
        # Cava raw output is a string of numbers separated by semicolons
        # e.g. "100;200;300;..."
        try:
            values = line.strip().split(';')
            # Remove empty strings if any
            values = [v for v in values if v]
            
            if len(values) < bars:
                continue

            # Normalize values (0-1000 usually, map to 0-100 for CSS height)
            # Cava raw output depends on bit_format. 16bit is 0-65535.
            # Let's scale it down.
            scaled_values = []
            for v in values[:bars]:
                val = int(v)
                # Simple scaling, adjust divisor based on your volume/cava sensitivity
                height = min(100, val / 200) 
                scaled_values.append(height)

            # Output JSON for Eww
            print(json.dumps(scaled_values), flush=True)
            
        except ValueError:
            continue

if __name__ == "__main__":
    main()
