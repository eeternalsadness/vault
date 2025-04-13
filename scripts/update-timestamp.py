#!/usr/bin/env python3

import yaml
import datetime
import sys

file_path = str(sys.argv[1])

# Load YAML
with open(file_path, "r") as f:
    data = yaml.safe_load(f)

# Ensure metadata exists
if "metadata" not in data:
    data["metadata"] = {}

# Update timestamp in RFC3339 (Terraform-compatible)
now_utc = datetime.datetime.now(datetime.UTC).replace(microsecond=0).isoformat()
data["metadata"]["timestamp"] = now_utc

# Write back to file
with open(file_path, "w") as f:
    yaml.safe_dump(data, f, default_flow_style=False)
