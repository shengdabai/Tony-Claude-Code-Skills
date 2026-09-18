# Dependency remediation — 2026-09-19

The remediation updates every manifest occurrence associated with the original 192 open Dependabot alerts (20 manifest paths), including duplicated project templates. Security alerts remain enabled. Closing a Dependabot pull request does not apply its dependency update.

## Changes

- Refresh the GetNote MCP dependency lock and raise SDK, Axios, form-data and Hono minimum versions.
- Upgrade Vitest and explicitly provide its Vite peer dependency in both alias-manager copies; refresh vulnerable transitive packages.
- Update all three FastAPI and TypeScript MCP templates. Convert the MCP prompt's string argument to a number before interpolation.
- Update diagram-render dependencies, diff, sharp, image-size, python-dotenv, the skills-ref lock, and copied global CLI manifests.
- Address additional FastAPI, Starlette and pyasn1 findings discovered by scanning the installed Python dependency tree.

## Validation

- GetNote TypeScript build; MCP initialization and tool listing with dummy credentials; mocked Axios success/error behavior.
- TypeScript template build; MCP prompt defaults and numeric string arguments; calculator tool call.
- Alias-manager tests (7), type checking and build; npm-registry audit reports no vulnerabilities.
- Diagram bundle build and 50 diagram/prepass tests; generated distribution artifacts remain excluded from this source collection.
- Sharp PNG generation, image dimensions and PPTX export; malformed zero-length ICNS input is rejected.
- Python dependency consistency; multipart upload, JWT signature validation and asyncio plugin tests; actual template health endpoint and token creation.
- Original advisory/version-range reconciliation covers all 192 occurrences. GitHub closure is confirmed separately after the default branch is rescanned.

## Remaining dependency finding

The Python template still installs `ecdsa` through `python-jose`. `GHSA-wj6h-64fc-37mp` / `CVE-2024-23342` describes timing leakage in python-ecdsa signing/key-generation operations; the upstream advisory lists no fixed version. The template defaults to HS256 and installs the cryptography backend. This does not remove the affected package or prove safety for callers choosing different algorithms/backends. The finding is not dismissed. Removing it requires replacing python-jose and validating that authentication migration separately.

## Synchronization

Installed skill/MCP sources can overwrite repository copies during automatic synchronization. Apply equivalent dependency changes to the maintained source before the next sync. Vendored duplicate manifests must remain consistent.
