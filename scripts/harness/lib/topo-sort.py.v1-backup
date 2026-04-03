#!/usr/bin/env python3
"""Topological sort for prd.json tasks.

Reads prd.json from stdin or file argument.
Outputs task IDs in execution order (one per line).
Marks dependents of blocked/skipped tasks as 'skipped' in the output.

Usage:
  python3 topo-sort.py prd.json
  cat prd.json | python3 topo-sort.py
"""
import json
import sys
from collections import defaultdict, deque


def topo_sort(tasks):
    """Return task IDs in dependency-resolved order, priority as tiebreaker."""
    graph = defaultdict(list)   # task_id -> [dependents]
    in_degree = {}
    task_map = {}
    blocked_or_done = set()

    for t in tasks:
        tid = t["id"]
        task_map[tid] = t
        in_degree[tid] = 0

    for t in tasks:
        tid = t["id"]
        deps = t.get("depends_on", [])
        for dep in deps:
            if dep in task_map:
                graph[dep].append(tid)
                in_degree[tid] = in_degree.get(tid, 0) + 1

    # Identify already done/blocked/skipped
    for t in tasks:
        if t["status"] in ("done", "blocked", "skipped"):
            blocked_or_done.add(t["id"])

    # Kahn's algorithm with priority tiebreaker
    queue = []
    for tid, deg in in_degree.items():
        if deg == 0:
            queue.append(tid)

    # Sort by priority (lower = higher priority)
    queue.sort(key=lambda tid: task_map[tid].get("priority", 999))

    result = []
    skip_set = set()

    while queue:
        # Pick highest priority (lowest number)
        queue.sort(key=lambda tid: task_map[tid].get("priority", 999))
        tid = queue.pop(0)
        task = task_map[tid]

        # Check if any dependency is blocked/skipped
        deps = task.get("depends_on", [])
        dep_blocked = any(d in blocked_or_done and task_map[d]["status"] in ("blocked", "skipped") for d in deps if d in task_map)

        if dep_blocked:
            skip_set.add(tid)
            blocked_or_done.add(tid)
            result.append({"id": tid, "action": "skip", "reason": f"depends on blocked task"})
        elif task["status"] == "pending":
            result.append({"id": tid, "action": "execute"})
        elif task["status"] in ("done", "blocked", "skipped"):
            result.append({"id": tid, "action": "skip", "reason": f"already {task['status']}"})
        else:
            result.append({"id": tid, "action": "execute"})

        for dep_tid in graph[tid]:
            in_degree[dep_tid] -= 1
            if in_degree[dep_tid] == 0:
                queue.append(dep_tid)

    # Check for cycles
    if len(result) != len(tasks):
        remaining = [t["id"] for t in tasks if t["id"] not in {r["id"] for r in result}]
        print(f"WARNING: Circular dependency detected for: {remaining}", file=sys.stderr)
        # Add remaining tasks anyway
        for tid in remaining:
            result.append({"id": tid, "action": "execute"})

    return result


def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1]) as f:
            data = json.load(f)
    else:
        data = json.load(sys.stdin)

    order = topo_sort(data["tasks"])
    print(json.dumps(order))


if __name__ == "__main__":
    main()
