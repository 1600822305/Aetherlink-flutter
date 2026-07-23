#!/usr/bin/env python3
"""Refresh assets/model_registry/models.json from cherry-studio provider-registry data.

Usage:
    python3 tool/update_model_registry.py <cherry-studio-repo-root> [version]

Reads packages/provider-registry/data/{models.json,provider-models.json} from the
cherry-studio checkout, slims each model down to id + capabilities + modalities,
and merges the result into the existing asset:

- ids present in the new cherry-studio data overwrite the old entries;
- ids only present in the old asset are preserved (legacy coverage);
- provider overrides contribute their capability patches (add/force unioned
  onto the base model's capabilities).

Output schema: {"version": str, "models": [{"i", "c"?, "in"?, "out"?}]},
sorted by id.
"""

import json
import sys
from datetime import date
from pathlib import Path

ASSET = Path(__file__).resolve().parent.parent / "assets/model_registry/models.json"


def effective_caps(base_caps, patch):
    caps = list(base_caps or [])
    if isinstance(patch, list):
        for c in patch:
            if c not in caps:
                caps.append(c)
    elif isinstance(patch, dict):
        for key in ("add", "force"):
            for c in patch.get(key, []):
                if c not in caps:
                    caps.append(c)
    return caps


def slim(model_id, caps, inputs, outputs):
    entry = {"i": model_id}
    if caps:
        entry["c"] = caps
    if inputs:
        entry["in"] = inputs
    if outputs:
        entry["out"] = outputs
    return entry


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cs_root = Path(sys.argv[1])
    version = sys.argv[2] if len(sys.argv) > 2 else date.today().strftime("%Y.%m.%d")
    data_dir = cs_root / "packages/provider-registry/data"

    base_models = json.loads((data_dir / "models.json").read_text())["models"]
    overrides = json.loads((data_dir / "provider-models.json").read_text())["overrides"]
    old = json.loads(ASSET.read_text())["models"]

    merged = {m["i"]: m for m in old}

    base_by_id = {}
    for m in base_models:
        base_by_id[m["id"]] = m
        merged[m["id"]] = slim(
            m["id"],
            m.get("capabilities"),
            m.get("inputModalities"),
            m.get("outputModalities"),
        )

    for o in overrides:
        for id_field in ("apiModelId", "modelId"):
            model_id = o.get(id_field)
            if not model_id:
                continue
            base = base_by_id.get(model_id, {})
            caps = effective_caps(base.get("capabilities"), o.get("capabilities"))
            inputs = o.get("inputModalities") or base.get("inputModalities")
            outputs = o.get("outputModalities") or base.get("outputModalities")
            prev = merged.get(model_id)
            entry = slim(model_id, caps, inputs, outputs)
            if prev is not None and model_id in base_by_id:
                # base entry already written; only union capability patches in
                for c in caps:
                    prev.setdefault("c", [])
                    if c not in prev["c"]:
                        prev["c"].append(c)
            else:
                merged[model_id] = entry

    out = {
        "version": version,
        "models": [merged[k] for k in sorted(merged)],
    }
    ASSET.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")) + "\n")
    print(f"wrote {len(out['models'])} models -> {ASSET}")


if __name__ == "__main__":
    main()
