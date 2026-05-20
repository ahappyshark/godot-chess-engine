#!/usr/bin/env python3
# compare_perft.py
# Usage: python3 compare_perft.py <reference> <mine>
# Defaults to sf_perft4.txt and my_perft4.txt if no args given.

import sys
import argparse


def parse_perft(filename):
    result = {}
    with open(filename) as f:
        for line in f:
            line = line.strip()
            if ': ' not in line:
                continue
            parts = line.split(': ', 1)
            move, count = parts[0].strip(), parts[1].strip()
            if not count.isdigit():
                continue
            if not all(c in 'abcdefgh12345678qrbn' for c in move):
                continue
            result[move] = int(count)
    return result


def compare(ref_file, my_file):
    ref = parse_perft(ref_file)
    mine = parse_perft(my_file)

    all_moves = sorted(set(ref.keys()) | set(mine.keys()))

    ref_total = sum(ref.values())
    my_total = sum(mine.values())
    total_diff = my_total - ref_total
    pct = (total_diff / ref_total * 100) if ref_total else 0

    print(f"Reference : {ref_file}  ({ref_total:,} nodes)")
    print(f"Mine      : {my_file}  ({my_total:,} nodes)")
    print(f"Total diff: {total_diff:+,}  ({pct:+.2f}%)")
    print()

    mismatches = []
    for move in all_moves:
        r = ref.get(move, None)
        m = mine.get(move, None)
        if r != m:
            mismatches.append((move, r, m))

    if not mismatches:
        print("All moves match.")
        return

    # Sort by absolute diff descending so worst offenders are at top
    def sort_key(row):
        _, r, m = row
        if isinstance(r, int) and isinstance(m, int):
            return abs(m - r)
        return float('inf')  # MISSING entries sort to top

    mismatches.sort(key=sort_key, reverse=True)

    print(f"{'Move':<10} {'Reference':>12} {'Mine':>12} {'Diff':>12} {'%':>8}")
    print("-" * 58)
    for move, r, m in mismatches:
        r_str = str(r) if r is not None else 'MISSING'
        m_str = str(m) if m is not None else 'MISSING'
        if isinstance(r, int) and isinstance(m, int):
            diff = m - r
            pct_move = diff / r * 100
            diff_str = f"{diff:+d}"
            pct_str = f"{pct_move:+.1f}%"
        else:
            diff_str = '?'
            pct_str = '?'
        print(f"{move:<10} {r_str:>12} {m_str:>12} {diff_str:>12} {pct_str:>8}")

    print()
    print(f"{len(mismatches)} mismatches out of {len(all_moves)} moves")

    # Recommend the best subtree to drill into (largest absolute diff among matched pairs)
    numeric = [(move, r, m) for move, r, m in mismatches if isinstance(r, int) and isinstance(m, int)]
    if numeric:
        drill_move, drill_r, drill_m = max(numeric, key=lambda x: abs(x[2] - x[1]))
        print(f"\n=> Drill into: {drill_move}  (ref={drill_r:,}, mine={drill_m:,}, diff={drill_m - drill_r:+,})")


REFERENCE_FILE = 'sf_e2e4_d7d5_e4d5.txt'
MY_FILE        = 'my_e2e4_d7d5_e4d5.txt'


def main():
    parser = argparse.ArgumentParser(
        description="Compare perft divide output between a reference engine (e.g. Stockfish) and yours."
    )
    parser.add_argument('ref', nargs='?', default=REFERENCE_FILE,
                        help=f'Reference perft output file (default: {REFERENCE_FILE})')
    parser.add_argument('mine', nargs='?', default=MY_FILE,
                        help=f'Your engine perft output file (default: {MY_FILE})')
    args = parser.parse_args()
    compare(args.ref, args.mine)


if __name__ == '__main__':
    main()
