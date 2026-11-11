# Contribution rules

## Branch ownership

- `feature/duy-application` owns `ssis/team/Duy_Application/`.
- `feature/hop-credit-history` owns `ssis/team/hop_credit_history/`.
- `feature/bao-payment-history` owns `ssis/team/bao_payment_history/`.
- Shared SQL changes require a separate pull request with the affected tests listed.

## Pull requests

1. Start from an up-to-date `main`.
2. Do not push directly to `main` or force-push it.
3. Keep each pull request limited to the owner's folder and directly related evidence/docs.
4. Require a review from a different owner before merging.
5. Include the commit SHA, canonical `BatchID`, run command, actual counts, and evidence paths.
6. Do not merge a runtime claim without a SQL result grid, execution log, or screenshot.

## Files that must not be committed

- Raw CSV files or generated full-data extracts.
- Credentials, passwords, tokens, private connection strings, or `.bak` files.
- `.vs/`, `bin/`, `obj/`, and `*.dtproj.user`.

Before committing, run:

```bash
git status --short
git diff --cached --name-only
python3 scripts/validate_project_artifacts.py
```
