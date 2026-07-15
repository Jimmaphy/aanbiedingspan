# ADR 0003: first vertical slice and dependency baseline

- Status: accepted
- Date: 2026-07-15

## Context

The repository contains product plans but no application. The first implementation
must prove the public journey and ranking before database-backed content management
adds migration and authorization complexity.

## Decision

- Use Swift 6, Vapor 4.122.0, Leaf 4.5.2, Fluent 4.13.0 and Fluent PostgreSQL
  Driver 2.12.0.
- Configure PostgreSQL from environment variables and provide Docker Compose for
  local development.
- Implement the public wizard, filtering, deterministic ranking, information pages,
  privacy opt-in and health routes as the first vertical slice.
- Keep demo catalog data immutable and behind an application storage boundary.
- Do not create an insecure partial admin portal. Database models, migrations,
  administrator sessions, CSRF and CRUD form the next vertical slice.

## Consequences

The first version is immediately usable and its most important business rule can be
tested without database fixtures. PostgreSQL infrastructure is ready, but the demo
catalog is not yet editable. The UI labels demo sources clearly and no automatic
source adapter is included.
