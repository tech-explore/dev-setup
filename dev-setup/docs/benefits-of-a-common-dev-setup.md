# Benefits of a Common Local Dev Setup Across the Team

A shared, scripted local environment turns "how do I get this running?" from a personal project into a solved problem. This document lists the benefits, the costs to plan for, and how to tell whether it is paying off.

## 1. Benefits

### Onboarding

- **Faster start for new developers.** One script and a short checklist replace days of installing tools, finding the right versions and asking colleagues for help.
- **Less dependence on individuals.** Setup knowledge lives in the repository, not in one person's head.

### Consistency

- **No "works on my machine".** Everyone runs the same versions of Postgres, Kafka, Redis, Java and Node, so a bug that appears for one person reproduces for everyone.
- **Reproducible bug reports and demos.** Anyone can recreate the same environment and state from the same files.
- **Predictable behaviour.** Differences caused by local installs, stray services or different configuration disappear.

### Quality

- **Closer to production.** Running on Kubernetes locally exposes configuration, service-name and networking problems early, not at deployment time.
- **Consistent CI.** The same manifests and the same `verify` step can run in the pipeline, so "passes locally" means more.
- **Earlier integration testing.** A full stack is always one command away, so integration problems surface while the code is fresh.

### Maintenance

- **Environment as code.** The setup lives in Git, so changes are reviewed, versioned and reversible.
- **Upgrade once, benefit everywhere.** Moving to a new Postgres version, or replacing an object store, is a single reviewed change.
- **Shared troubleshooting.** A problem solved once goes into the troubleshooting table and is solved for the whole team.

### Security and cost

- **Shared conventions for secrets.** Dev credentials, ports and naming are decided once, which reduces ad hoc and risky choices.
- **Less wasted time.** Fewer hours lost to environment problems is direct, measurable savings.

## 2. Costs and risks (and how to manage them)

| Risk | Mitigation |
|---|---|
| Someone has to own and maintain the setup | Name an owner or a small rotation, and treat the setup like any other product |
| A rigid setup frustrates people with different needs | Keep a documented way to override ports, memory and versions locally |
| The setup drifts from production | Review it whenever production changes (versions, configuration, new services) |
| Heavy resource use on laptops | Provide `task down`, scaling instructions and the Performance Optimization Guide |
| Windows-only scripts exclude other platforms | Add shell equivalents if the team grows beyond Windows (see the improvement roadmap) |
| Dev credentials leak into other places | Keep them clearly labelled dev-only, and never reuse them outside local environments |

## 3. How to tell it is working

Track a few simple measures before and after adopting the shared setup:

- **Time to first running stack** for a new teammate (target: under an hour).
- **Setup-related questions** in team chat per month.
- **"Works on my machine" bugs** reported or reopened.
- **CI versus local mismatches**, meaning builds that pass locally and fail in the pipeline.
- **Environment-related incidents** during demos or reviews.

## 4. How this package supports a shared setup

- `setup-dev.ps1` installs the Windows tools and skips what is already installed.
- `k8s-dev/` defines the infrastructure as versioned manifests.
- `Taskfile.yml` gives everyone the same commands: `task doctor`, `task up`, `task verify`, `task down`, `task reset`.
- `scripts/doctor.ps1` and `scripts/verify.ps1` replace guesswork with clear pass and fail output.
- The setup manual and the architecture document explain the why and the how.
- See `improvement-roadmap.md` for what to add next.
