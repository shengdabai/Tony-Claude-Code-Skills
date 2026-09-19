# Dependency remediation — 2026-09-19

The remediation updates every manifest occurrence associated with the original 192 open Dependabot alerts (20 manifest paths), including duplicated project templates. Security alerts remain enabled. Closing a Dependabot pull request does not apply its dependency update.

## Changes

- Refresh the GetNote MCP dependency lock and raise SDK, Axios, form-data and Hono minimum versions.
- Upgrade Vitest and explicitly provide its Vite peer dependency in both alias-manager copies; refresh vulnerable transitive packages.
- Update all three FastAPI and TypeScript MCP templates. Convert the MCP prompt's string argument to a number before interpolation; update httpx transport and pytest-asyncio fixture examples.
- Update diagram-render dependencies, diff, sharp, image-size, python-dotenv, the skills-ref lock, and copied global CLI manifests.
- Address additional FastAPI, Starlette and pyasn1 findings discovered by scanning the installed Python dependency tree.

## Validation

- GetNote TypeScript build; MCP initialization and tool listing with dummy credentials; mocked Axios success/error behavior.
- TypeScript template build; MCP prompt defaults and numeric string arguments; calculator tool call.
- Alias-manager tests (7), type checking and build; npm-registry audit reports no vulnerabilities.
- Diagram bundle build and 50 diagram/prepass tests; real-browser Mermaid SVG/PNG and Excalidraw conversion/export checks. Generated distribution artifacts remain excluded from this source collection.
- Node requirements are explicit for the Vitest templates/alias manager and sharp-based exporter. Sharp PNG generation, image dimensions and PPTX export; malformed zero-length ICNS input is rejected.
- Python dependency consistency; multipart upload, JWT signature validation and asyncio plugin tests; actual template health endpoint and token creation.
- The independent review also reconciled all 192 occurrences with no missing mappings or vulnerable resolutions. Original advisory/version-range reconciliation covers all 192 occurrences. GitHub closure is confirmed separately after the default branch is rescanned.

## Indirect ECDSA dependency removed

The three FastAPI copies now use `PyJWT[crypto]==2.14.0` instead of `python-jose`. The old package unconditionally installed `ecdsa`, affected by `GHSA-wj6h-64fc-37mp` / `CVE-2024-23342`, even when the cryptography backend was selected. The replacement removes that dependency path rather than suppressing the advisory. The now-orphaned direct `pyasn1` constraint is removed as well.

- A fresh Python 3.11 environment installs the complete template requirements. `pip check` passes; installed-tree `pip-audit` reports **0 known vulnerabilities across 100 packages**, including audit tooling. Distribution metadata confirms that `python-jose`, `ecdsa`, `rsa`, and `pyasn1` are absent.
- Each of the three copies passes 54 JWT regressions in a separate Python process. Public synthetic access/refresh fixtures generated with python-jose 3.5.0 remain valid. New token creation, missing-user rejection, optional claims and scope authorization are covered.
- Invalid signatures, unsigned/disallowed algorithms, expired/malformed tokens, missing/non-string subjects and unsupported audience/OpenID hash claims retain the 401 response and Bearer header at the scaffold and reusable middleware consumers. Explicit guards preserve jose's rejection of present `aud`/`at_hash` claims; no verifier is disabled. Configured RSA/EC private keys are converted to their public half for verification. Actual scaffold and middleware tests cover RS256/ES256 issuance, successful authentication and wrong-key rejection; all generated keys stay in memory. The cryptography-backed path works without python-ecdsa.
- PyJWT's stricter future-`iat` and expiration-boundary handling is retained. The scaffold does not issue `iat`. No keys are rotated and no real account, database or external service is used for validation.
- Tests stub the database lookup to isolate the JWT boundary. The pre-existing `crud.user.get(..., id=...)` versus `get(db, user_id)` mismatch is outside this migration and remains unresolved; these checks do not claim a complete database login-flow test. Other baseline authentication limitations remain: those consumers do not distinguish access from refresh tokens, a nonnumeric string subject can fail integer conversion, and the reference scope example lacks JWT-to-HTTP error mapping. This dependency migration does not claim to repair those separate application-policy defects.

Regression tests and synthetic fixtures live in each FastAPI skill's `tests/` directory. With that copy's template requirements installed, run `python -m pytest tests/test_jwt_migration.py -q` from the skill directory.

## Synchronization

Installed skill/MCP sources can overwrite repository copies during automatic synchronization. The user explicitly requested that the installed GetNote, gstack and huashu-design sources remain unchanged. Their prior dependency changes therefore remain repository-only; a later source sync may reintroduce older dependencies. Vendored duplicate manifests must remain consistent.
