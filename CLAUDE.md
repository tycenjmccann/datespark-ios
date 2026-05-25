# DateSpark Web Backend - Project Conventions

## Architecture
- **Framework:** Next.js 14+ with App Router
- **Language:** TypeScript (strict mode)
- **Runtime:** Node.js 20+
- **Cloud:** AWS (S3, DynamoDB, Cognito)

## Code Style
- ESLint + Prettier
- Explicit return types on exported functions
- Prefer named exports
- Use `async/await` over raw Promises
- Errors must be typed or wrapped in custom error classes

## File Structure
```
src/
├── app/              # Next.js App Router (API routes, pages)
│   └── api/          # API route handlers
├── lib/              # Shared utilities, AWS clients, helpers
│   └── __tests__/    # Unit tests co-located with lib
├── components/       # React components (if applicable)
└── types/            # Shared TypeScript types
```

## AWS SDK
- Use AWS SDK v3 (modular imports)
- Client instances created once, reused
- Environment variables for all config (never hardcode)
- Presigned URLs: use `@aws-sdk/s3-request-presigner`

## Testing
- Framework: Vitest (preferred) or Jest
- Mock AWS SDK calls in unit tests
- Test files: `__tests__/*.test.ts`
- Minimum coverage: statements 80%

## Environment Variables
- `S3_BUCKET_NAME` — S3 bucket for profile photos
- `AWS_REGION` — AWS region
- `NEXTAUTH_SECRET` — Auth secret
- Never commit `.env` files

## API Conventions
- Return JSON with consistent shape: `{ data?, error?, message? }`
- Use appropriate HTTP status codes
- Validate input before processing
- Log errors with context (userId, operation)
