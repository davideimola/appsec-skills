# Skills only, no code template

This repo ships Agent Skills, not a `gonew` service template. The talk's audience mostly has services already in production, and a skill adapts to their repo (monorepos, existing workflows, private modules) where a copied file breaks. Go code lives only in `testdata/fixture/`, to test what the skills produce and to give agents a reference example.

## Considered Options

- **`gonew` template with a full service skeleton**: rejected. It serves only people starting a new service and drags in opinions unrelated to security.
- **Template plus skills (hybrid)**: rejected. It keeps two products alive for the same promise.
- **Importable library** (`go get .../httpx`): rejected. It adds a supply chain dependency to every user, the opposite of what the talk recommends, and commits us to a stable API.
