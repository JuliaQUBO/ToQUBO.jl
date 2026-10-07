"""Validate GitHub's publication queue, then run the unchanged actionlint checker.

actionlint 1.7.12 has no parser for concurrency.queue. Remove only a separately
validated queue property from the lint input; retain all other workflow checks.
The original files and runtime workflow are never rewritten.
"""
import argparse
from pathlib import Path
import subprocess

import yaml


def lint_input(text):
    """Reject unsafe queue shapes before presenting compatible input to lint."""
    data = yaml.load(text, Loader=yaml.BaseLoader)
    mappings = []
    if isinstance(data, dict):
        mappings.append(data)
        mappings.extend((data.get("jobs") or {}).values())
    queues = [mapping["concurrency"] for mapping in mappings
              if isinstance(mapping, dict)
              and isinstance(mapping.get("concurrency"), dict)
              and "queue" in mapping["concurrency"]]
    for queue in queues:
        if (queue.get("queue") != "max"
                or queue.get("cancel-in-progress") != "false"
                or queue.get("group") != "documentation-publishing"):
            raise ValueError("Publication queue must be max, non-cancelling and destination-wide")
    # Locate only concurrency.queue nodes; preserve line numbers and other text.
    tree = yaml.compose(text)
    remove = set()

    def walk(node):
        if isinstance(node, yaml.MappingNode):
            keys = [key.value for key, _ in node.value]
            if len(set(keys)) != len(keys):
                raise ValueError("Duplicate workflow keys are invalid")
            for key, value in node.value:
                if key.value == "concurrency" and isinstance(value, yaml.MappingNode):
                    for child_key, child_value in value.value:
                        if child_key.value == "queue":
                            if child_key.start_mark.line != child_value.end_mark.line:
                                raise ValueError("Publication queue must use a scalar on one line")
                            line = text.splitlines()[child_key.start_mark.line].strip()
                            if line != "queue: max":
                                raise ValueError("Publication queue must use its own line")
                            remove.add(child_key.start_mark.line)
                walk(value)
        elif isinstance(node, yaml.SequenceNode):
            for value in node.value:
                walk(value)

    walk(tree)
    if len(remove) != len(queues):
        raise ValueError("Queue properties are only allowed on workflow/job concurrency")
    return "".join("\n" if i in remove else line
                   for i, line in enumerate(text.splitlines(keepends=True)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", help="Existing pinned actionlint container")
    parser.add_argument("paths", nargs="*", help="Workflow files; defaults to all")
    args = parser.parse_args()
    command = (["docker", "run", "--rm", "-i", "-v", f"{Path.cwd()}:/repo",
                "--workdir", "/repo", args.image] if args.image else ["actionlint"])
    paths = [Path(p) for p in args.paths] or sorted(Path(".github/workflows").glob("*.y*ml"))
    for path in paths:
        print(path, flush=True)
        subprocess.run(command + ["-"], input=lint_input(path.read_text()),
                       text=True, check=True)


if __name__ == "__main__":
    main()
