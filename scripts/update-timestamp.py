#!/usr/bin/env python3

import yaml
import sys

file_path = str(sys.argv[1])
timestamp = str(sys.argv[2])

# Load YAML
with open(file_path, "r") as f:
    data = yaml.safe_load(f)

# Ensure metadata exists
if "metadata" not in data:
    data["metadata"] = {}

# Update timestamp
data["metadata"]["timestamp"] = timestamp

# Write back to file
with open(file_path, "w") as f:
    yaml.safe_dump(data, f, default_flow_style=False)
