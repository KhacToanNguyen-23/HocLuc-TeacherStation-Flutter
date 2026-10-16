# Google desktop runtime configuration
Mode: fast planning; implementation with verification
Risk: high-risk — OAuth configuration and persistent encryption key

Scope: use existing Spring configuration mechanisms for the backend and existing frontend URL defaults.

- [x] Load desktop client JSON at backend startup, preserving environment overrides.
- [x] Generate and reuse a local encryption key without deriving it from client credentials.
- [x] Verify configuration precedence, restart behavior, invalid input and architecture tests.

Verification: Maven test passed (111 tests, zero failures/errors); Maven package
passed; Flutter architecture tests passed (5 tests); git diff --check passed.
Independent static review found no blocking issues. Real Google consent/exchange
was not exercised without supplied credentials. Concurrent first startup has a
small race while initially writing the key; normal single-backend startup is supported.

Desktop client JSON and .env remain local and ignored at the user's request.
Only .env.example placeholders are tracked. Local encryption keys,
machine configuration, SDKs and personal setup scripts remain ignored.
