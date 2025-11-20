# T.A.S.K.S.

![task-bash-social](https://github.com/user-attachments/assets/c06b77db-9e1c-4cea-adad-785097ca58b1)


***T**asks **A**re **S**equenced **K**ey **S**teps** is a file-system-based autonomous agent runner. It turns a goal into a dependency-ordered DAG, manages tasks via the filesystem, and drives parallel LLM workers to get the work done.

> [!WARNING]
> This gives an LLM write access to your workspace. Run inside git (or a Docker container that copies the repo in) so you can revert if things go sideways.

> [!CAUTION]
> USE AT YOUR OWN RISK. If you run this software, you're unleashing the swarm. Not one LLM going buck wild. Unsupervised. Multiple LLMs.  
> 🥀
> May Claude have mercy on your repo.

## Architecture (Filesystem = Database)

- **1_architect.sh (Architect)**: scans the project and prompts an LLM to emit a JSON DAG.
- **2_seeder.sh (Seeder)**: converts the DAG into per-task JSON files, placing them in `open/` or `blocked/` based on dependencies.
- **3_overlord.sh (Overlord)**: main loop that unblocks tasks when deps close, throttles workers, and spawns minions.
- **4_minion.sh (Minion)**: runs one task via LLM, updates state, and logs output.
- **5_status.sh (Dashboard)**: live view of the state machine.
- **6_revive.sh (Reviver)**: moves failed tasks back to `open/` for retry.

## Prerequisites

- Bash (macOS/Linux/WSL)
- `jq` for JSON parsing
  - macOS: `brew install jq`
  - Linux: `sudo apt-get install jq`
- LLM CLI tool: defaults to `claude`; any executable that accepts the prompt as the final argument and prints to stdout will work.

## Quick Start

```bash
# 0) Make scripts executable
chmod +x *.sh

# 1) Initialize directories and env vars
./setup.sh

# 2) Generate a plan (DAG)
./1_architect.sh "Refactor auth to use JWTs"

# 3) Seed tasks
./2_seeder.sh

# 4) Monitor (separate terminal)
./5_status.sh

# 5) Unleash the swarm
./3_overlord.sh
```

## State Machine (`.tasks/`)

```
.tasks/
├── manifest/        # The Architect's original plan (dag.json)
├── prompts/         # System prompts generated for the LLMs
├── blocked/         # 🛑 Tasks waiting for dependencies to complete
├── open/            # 🟢 Tasks ready to be picked up by workers
├── claimed/         # 🚀 Tasks currently being executed (Mutex Lock)
│   └── w_<id>/      #    (Atomic directory per active worker)
├── closed/          # 🏁 Successfully completed tasks
├── dead/            # 💀 Tasks that failed (exit code != 0)
└── logs/            # 📄 Stdout/Stderr logs for every execution
```

## Configuration & LLM Swaps

All config lives in `setup.sh`. You can override via env vars before running:

- `MAX_WORKERS` (default `4`): cap concurrent workers.
- `LLM_PLANNER_CMD` (default `claude -p`): planner that outputs JSON.
- `LLM_WORKER_CMD` (default `claude --dangerously-skip-permissions`): worker used for edits.

Example using a Python OpenAI wrapper:

```python
# gpt_runner.py
import sys
prompt = sys.argv[-1]
# ... call OpenAI ...
print(response_content)
```

```bash
export LLM_PLANNER_CMD="python3 gpt_runner.py"
export LLM_WORKER_CMD="python3 gpt_runner.py"
```

## Components At a Glance

| Script          | Role                                      |
|-----------------|-------------------------------------------|
| setup.sh        | Global config; creates directory scaffold |
| 1_architect.sh  | Builds context and writes `dag.json`      |
| 2_seeder.sh     | DAG -> per-task files in .tasks           |
| 3_overlord.sh   | Dependency resolution + worker spawning   |
| 4_minion.sh     | Executes a single task via LLM            |
| 5_status.sh     | Dashboard for current state               |
| 6_revive.sh     | Moves `dead/` tasks back to `open/`       |

## Troubleshooting

- **System looks stuck**: run `./5_status.sh`.
  - If tasks sit in `blocked/`, check that their deps are in `closed/`; restart `./3_overlord.sh` if needed.
  - If tasks pile in `dead/`, inspect `.tasks/logs/<task_id>.log`.
- **Revive failed tasks**: `./6_revive.sh` moves `dead/` -> `open/`.
- **Plans lack context**: bump scan depth in `1_architect.sh` (`find . -maxdepth 6 ...`).

## Testing

Dockerized Bats suite lives in `tests/`. Run everything in isolation:

```bash
./run-tests.sh
```

---

## License

MIT
_© 2025 James Ross • [Flying•Robots](https://github.com/flyingrobots)_
_All Rights Reserved_
