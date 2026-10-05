#!/usr/bin/env python3
"""Small Python-3.6-compatible numeric helpers for HPC shell workflows."""

from __future__ import print_function

import sys


def numbers_from_stdin():
    rows = []
    for line in sys.stdin:
        fields = line.split()
        if fields:
            rows.append(fields)
    return rows


def main():
    command = sys.argv[1]
    args = sys.argv[2:]
    if command == "metadata":
        path, key = args
        with open(path, "r") as handle:
            for line in handle:
                name, separator, value = line.rstrip("\r\n").partition("=")
                if separator and name == key:
                    print(value)
                    return 0
        return 1
    if command == "first":
        with open(args[0], "r") as handle:
            for line in handle:
                stripped = line.strip()
                if stripped and not stripped.startswith("#"):
                    print(stripped.split()[0])
                    return 0
        return 1
    if command == "positive":
        return 0 if all(float(value) > 1.0e-10 for value in args) else 1
    if command == "continuation":
        previous_mass, current_mass, previous_field, current_field = map(float, args)
        return 0 if current_mass > previous_mass * 1.0e-4 and current_field > previous_field * 1.0e-4 else 1
    if command == "divide":
        print("{:.17g}".format(float(args[0]) / float(args[1])))
        return 0
    if command == "close":
        return 0 if abs(float(args[0]) - float(args[1])) < float(args[2]) else 1
    if command == "scale":
        print("{:.17g}".format(float(args[0]) / float(args[1])))
        return 0
    if command == "one-plus":
        print("{:.17g}".format(1.0 + float(args[0])))
        return 0
    if command == "grow":
        print("{:.17g}".format(min(float(args[0]) * 1.25, float(args[1]))))
        return 0
    if command == "half":
        print("{:.17g}".format(float(args[0]) / 2.0))
        return 0
    if command == "ge":
        return 0 if float(args[0]) >= float(args[1]) else 1
    if command == "line-count":
        with open(args[0], "r") as handle:
            print(sum(1 for _ in handle))
        return 0
    if command == "line-count-minus-one":
        with open(args[0], "r") as handle:
            print(sum(1 for _ in handle) - 1)
        return 0
    if command == "min-second":
        rows = numbers_from_stdin()
        if rows:
            print(min(rows, key=lambda row: float(row[0]))[1])
            return 0
        return 1
    if command == "internal-maximum":
        rows = sorted(numbers_from_stdin(), key=lambda row: float(row[0]))
        if len(rows) < 3:
            return 1
        maximum_index = max(range(len(rows)), key=lambda index: float(rows[index][1]))
        return 0 if 0 < maximum_index < len(rows) - 1 else 1
    if command == "csv-success":
        path, label = args
        with open(path, "r") as handle:
            for line in handle:
                fields = [field.strip() for field in line.split(",")]
                if len(fields) >= 6 and fields[0] == label and fields[5] == "0":
                    return 0
        return 1
    raise ValueError("unknown numeric helper command: {}".format(command))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (IOError, OSError, ValueError, IndexError) as exc:
        sys.stderr.write("numeric_helper: {}\n".format(exc))
        sys.exit(2)
