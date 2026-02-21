import Link from "next/link";

export default function Home() {
  const curlExample = `curl -X POST http://localhost:3000/api/reading \\
  -H 'Content-Type: application/json' \\
  -d '{
  "client": {
    "name": "David",
    "age": 41,
    "situation": "He owns a restaurant. His business partner has been stealing from him for two years."
  },
  "slots": [
    {
      "index": 0,
      "card": "the_moon",
      "text": "You found the second ledger in March, hidden in the office behind the wine inventory. You closed it and put it back."
    },
    {
      "index": 1,
      "card": "justice",
      "text": null
    },
    {
      "index": 2,
      "text": null
    }
  ]
}'`;

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100 p-8 font-mono">
      <div className="max-w-3xl mx-auto">
        <h1 className="text-2xl font-bold mb-2 text-zinc-100">Tarot Reading API</h1>
        <p className="text-zinc-400 mb-8">
          REST API for generating tarot card readings using Claude.
        </p>

        <div className="mb-8">
          <Link
            href="/play"
            className="inline-block bg-zinc-800 hover:bg-zinc-700 text-zinc-100 px-5 py-2.5 rounded text-sm transition-colors"
          >
            Open Debug UI →
          </Link>
        </div>

        <div className="space-y-6">
          <section>
            <h2 className="text-sm font-semibold text-zinc-400 uppercase tracking-widest mb-3">Endpoints</h2>
            <div className="space-y-2 text-sm">
              <div className="flex gap-3">
                <span className="text-emerald-400 w-12">POST</span>
                <span className="text-zinc-200">/api/reading</span>
                <span className="text-zinc-500">— generate text for the next empty slot</span>
              </div>
              <div className="flex gap-3">
                <span className="text-sky-400 w-12">GET</span>
                <span className="text-zinc-200">/api/cards</span>
                <span className="text-zinc-500">— list all 78 cards</span>
              </div>
              <div className="flex gap-3">
                <span className="text-sky-400 w-12">GET</span>
                <span className="text-zinc-200">/api/clients</span>
                <span className="text-zinc-500">— list all clients</span>
              </div>
            </div>
          </section>

          <section>
            <h2 className="text-sm font-semibold text-zinc-400 uppercase tracking-widest mb-3">Example</h2>
            <pre className="bg-zinc-900 border border-zinc-800 rounded p-4 text-xs text-zinc-300 overflow-x-auto whitespace-pre-wrap">
              {curlExample}
            </pre>
          </section>

          <section>
            <h2 className="text-sm font-semibold text-zinc-400 uppercase tracking-widest mb-3">Request Schema</h2>
            <pre className="bg-zinc-900 border border-zinc-800 rounded p-4 text-xs text-zinc-300 overflow-x-auto">{`{
  "client": {
    "name": string,
    "age": number,          // optional
    "situation": string     // required — who they are and what's happening
  },
  "slots": [
    {
      "index": number,        // 0, 1, or 2
      "card": string | null,  // card name from /api/cards (e.g. "the_moon")
      "text": string | null   // null = not yet generated
    }
  ]
}`}</pre>
          </section>

          <section>
            <h2 className="text-sm font-semibold text-zinc-400 uppercase tracking-widest mb-3">Response Schema</h2>
            <pre className="bg-zinc-900 border border-zinc-800 rounded p-4 text-xs text-zinc-300 overflow-x-auto">{`{
  "client": { ... },           // same as input
  "slots": [ ... ],            // same as input with target slot's text filled
  "generated": string,         // the text that was generated
  "filled_slot": number        // which slot index was filled (0, 1, or 2)
}`}</pre>
          </section>
        </div>
      </div>
    </div>
  );
}
