#!/usr/bin/env python3
"""Plot dungeon run metrics from exported CSV files.

Usage:
    python plot_metrics.py <csv_path> [game_number]
    python plot_metrics.py <csv_path> <start_game_number> <end_game_number>
"""

import csv
import os
import re
import sys
from collections import defaultdict

try:
    import matplotlib.pyplot as plt
except ImportError:
    print("Missing dependency: matplotlib")
    print("Install with: py -3 -m pip install matplotlib")
    raise


def _to_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _to_int(value, default=0):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def parse_enemy_counts(enemy_counts_text):
    counts = {}
    if not enemy_counts_text:
        return counts

    text = enemy_counts_text.strip()
    if not text or text.lower() == "none":
        return counts

    parts = re.split(r";\s*", text)
    for part in parts:
        if "=" not in part:
            continue
        name, value = part.split("=", 1)
        counts[name.strip()] = _to_float(value.strip(), 0.0)
    return counts


def read_rows(csv_path):
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    with open(csv_path, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = [row for row in reader]

    if not rows:
        raise RuntimeError("CSV file has no data rows yet.")

    return rows


def choose_game_rows(rows, requested_game_number=None, requested_end_game_number=None):
    game_numbers = [_to_int(r.get("GameNumber"), 0) for r in rows]
    valid_games = [g for g in game_numbers if g > 0]
    if not valid_games:
        return rows, 0, 0

    if requested_end_game_number is not None:
        start_game = requested_game_number
        end_game = requested_end_game_number
        if start_game is None or start_game <= 0 or end_game <= 0 or end_game < start_game:
            raise RuntimeError("Invalid game range requested for plotting")
        selected = [
            r for r in rows
            if start_game <= _to_int(r.get("GameNumber"), 0) <= end_game
        ]
        if not selected:
            raise RuntimeError(f"No rows found for GameNumber range {start_game}-{end_game}")
        return selected, start_game, end_game

    if requested_game_number is None:
        game = max(valid_games)
    else:
        game = requested_game_number

    selected = [r for r in rows if _to_int(r.get("GameNumber"), 0) == game]
    if not selected:
        raise RuntimeError(f"No rows found for GameNumber={game}")
    return selected, game, game


def build_series(rows):
    rows_sorted = sorted(
        rows,
        key=lambda r: (_to_int(r.get("GameNumber"), 0), _to_int(r.get("RunNumber"), 0)),
    )

    game_numbers = [_to_int(r.get("GameNumber"), 0) for r in rows_sorted]
    runs = [_to_int(r.get("RunNumber"), 0) for r in rows_sorted]
    enemy_total = [_to_float(r.get("EnemyCount"), 0.0) for r in rows_sorted]
    damage_to_player = [_to_float(r.get("DamageToPlayer"), 0.0) for r in rows_sorted]
    ai_score = [_to_float(r.get("AIScorePercent"), 0.0) for r in rows_sorted]

    enemy_by_type = defaultdict(list)
    enemy_types_order = []

    for r in rows_sorted:
        parsed = parse_enemy_counts(r.get("EnemyTypeCounts", ""))

        for enemy_name in parsed.keys():
            if enemy_name not in enemy_by_type:
                enemy_types_order.append(enemy_name)

        for enemy_name in enemy_types_order:
            enemy_by_type[enemy_name].append(parsed.get(enemy_name, 0.0))

    return game_numbers, runs, enemy_total, enemy_by_type, damage_to_player, ai_score


def plot_metrics(csv_path, game_number=None, end_game_number=None):
    rows = read_rows(csv_path)
    selected_rows, resolved_start_game, resolved_end_game = choose_game_rows(
        rows,
        game_number,
        end_game_number,
    )
    include_multiple_games = resolved_end_game > resolved_start_game

    game_numbers, runs, enemy_total, enemy_by_type, damage_to_player, ai_score = build_series(selected_rows)
    if include_multiple_games:
        x_axis = list(range(1, len(runs) + 1))
    else:
        x_axis = runs

    fig, axes = plt.subplots(3, 1, figsize=(12, 14), sharex=True)

    axes[0].plot(x_axis, enemy_total, linewidth=2.5, color="#1f77b4", label="Total Enemies")
    axes[0].set_title("Enemies Over Runs")
    axes[0].set_ylabel("Enemy Count")
    axes[0].grid(True, alpha=0.3)
    axes[0].legend(loc="upper left")

    if enemy_by_type:
        for enemy_name, values in enemy_by_type.items():
            axes[1].plot(x_axis, values, linewidth=1.8, label=enemy_name)
        axes[1].legend(loc="upper left", ncol=2, fontsize=8)
    axes[1].set_title("Enemy Types Over Runs")
    axes[1].set_ylabel("Count per Type")
    axes[1].grid(True, alpha=0.3)

    axes[2].plot(x_axis, ai_score, linewidth=2.5, color="#2ca02c", label="AI Score %")
    axes[2].plot(x_axis, damage_to_player, linewidth=1.8, color="#d62728", alpha=0.7, label="Damage To Player")
    axes[2].set_title("AI Learning / Behavior Shift Over Time")
    if include_multiple_games:
        axes[2].set_xlabel("Selected Games (sequential run index)")
    else:
        axes[2].set_xlabel("Run Number")
    axes[2].set_ylabel("Score / Damage")
    axes[2].grid(True, alpha=0.3)
    axes[2].legend(loc="upper left")

    if include_multiple_games and game_numbers:
        boundary_positions = []
        tick_positions = []
        tick_labels = []

        previous_game = game_numbers[0]
        tick_positions.append(x_axis[0])
        tick_labels.append(f"G{previous_game}")

        for i in range(1, len(game_numbers)):
            current_game = game_numbers[i]
            if current_game != previous_game:
                boundary_positions.append(x_axis[i] - 0.5)
                tick_positions.append(x_axis[i])
                tick_labels.append(f"G{current_game}")
                previous_game = current_game

        for ax in axes:
            for x in boundary_positions:
                ax.axvline(x=x, color="#888888", linewidth=0.8, alpha=0.45)

        axes[2].set_xticks(tick_positions)
        axes[2].set_xticklabels(tick_labels)

    title = os.path.basename(csv_path)
    if include_multiple_games:
        fig.suptitle(f"{title} - Games {resolved_start_game} to {resolved_end_game}", fontsize=14)
    else:
        fig.suptitle(f"{title} - Game {resolved_start_game}", fontsize=14)

    plt.tight_layout()
    plt.show()


def main():
    if len(sys.argv) < 2:
        print("Usage: python plot_metrics.py <csv_path> [game_number]")
        print("   or: python plot_metrics.py <csv_path> <start_game_number> <end_game_number>")
        return 1

    csv_path = sys.argv[1]
    game_number = None
    end_game_number = None

    if len(sys.argv) >= 3:
        game_number = _to_int(sys.argv[2], None)
    if len(sys.argv) >= 4:
        end_game_number = _to_int(sys.argv[3], None)

    try:
        plot_metrics(csv_path, game_number, end_game_number)
    except Exception as exc:
        print(f"Failed to plot metrics: {exc}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
