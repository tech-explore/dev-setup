// app/stack-check/page.tsx
// Server component: the fetch runs on the Next.js server, so inside Kubernetes
// BACKEND_URL can be a cluster address like http://demo-service:8080.

export const dynamic = 'force-dynamic'; // always run the checks, never cache the page

type CheckResult = {
  status: string;
  detail?: string;
  error?: string;
  ms: number;
};

const SERVICES = ['postgres', 'redis', 'kafka', 's3'] as const;

export default async function StackCheckPage() {
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
    <main style={{ fontFamily: 'system-ui, sans-serif', maxWidth: 640, margin: '2rem auto' }}>
      <h1>Stack check</h1>
      <p>
        Backend: <code>{base}</code>
      </p>

      {failure && <p style={{ color: 'crimson' }}>{failure}</p>}

      {data && (
        <>
          <h2>Overall: {String(data.overall)}</h2>
          <ul style={{ listStyle: 'none', padding: 0 }}>
            {SERVICES.map((name) => {
              const r = data![name] as CheckResult | undefined;
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
    </main>
  );
}
