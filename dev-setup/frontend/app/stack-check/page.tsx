// app/stack-check/page.tsx  (or src/app/stack-check/page.tsx)
//
// Server component. With `cacheComponents` enabled:
//  - the route segment option `export const dynamic` is not allowed, so it is not used here;
//  - uncached data (the fetch below) must be read inside a <Suspense> boundary.
// The fetch runs on the Next.js server, so inside Kubernetes BACKEND_URL can be a
// cluster address like http://demo-service:8080.

import { Suspense } from 'react';
import { connection } from 'next/server';

type CheckResult = {
  status: string;
  detail?: string;
  error?: string;
  ms: number;
};

const SERVICES = ['postgres', 'redis', 'kafka', 's3'] as const;

export default function StackCheckPage() {
  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', maxWidth: 640, margin: '2rem auto' }}>
      <h1>Stack check</h1>
      <Suspense fallback={<p>Running checks…</p>}>
        <Results />
      </Suspense>
    </main>
  );
}

async function Results() {
  // Opt in to request-time rendering: run the checks on every request, never at build time
  await connection();

  const base = process.env.BACKEND_URL ?? 'http://localhost:8080';

  let data: Record<string, unknown> | null = null;
  let failure: string | null = null;

  try {
    // /check answers 503 with a JSON body when a service is down, so parse either way
    const res = await fetch(`${base}/check`, { cache: 'no-store' });
    data = await res.json();
  } catch (e) {
    failure = `Could not reach the backend at ${base}: ${(e as Error).message}`;
  }

  return (
    <>
      <p>
        Backend: <code>{base}</code>
      </p>

      {failure && <p style={{ color: 'crimson' }}>{failure}</p>}

      {data && (
        <>
          <h2>Overall: {String(data.overall)}</h2>
          <ul style={{ listStyle: 'none', padding: 0 }}>
            {SERVICES.map((name) => {
              const r = data[name] as CheckResult | undefined;
              const up = r?.status === 'UP';
              return (
                <li key={name} style={{ marginBottom: '0.75rem' }}>
                  <strong>
                    {up ? '✅' : '❌'} {name}
                  </strong>{' '}
                  {r ? `(${r.ms} ms)` : ''}
                  <div style={{ color: up ? 'inherit' : 'crimson' }}>
                    {r ? (up ? r.detail : r.error) : 'no result'}
                  </div>
                </li>
              );
            })}
          </ul>
        </>
      )}
    </>
  );
}
