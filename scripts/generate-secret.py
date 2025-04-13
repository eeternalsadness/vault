#!/usr/bin/env python3

import json
import secrets
import string
import sys


def generate_secret(length=16, symbols=True):
    chars = string.ascii_letters + string.digits
    if symbols:
        chars += "!@#$%^&*-_=+;:,./?"
    return "".join(secrets.choice(chars) for _ in range(length))


def main():
    input_data = json.load(sys.stdin)
    length = int(input_data.get("length", 16))
    symbols = str(input_data.get("symbols", "true")) == "true"

    result = {"secret": generate_secret(length, symbols)}

    print(json.dumps(result))


if __name__ == "__main__":
    main()
