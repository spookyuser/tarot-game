"use client";

import { useEffect, useState } from "react";

interface CardDef {
  name: string;
  arcana: string;
  suit: string;
  value: string;
  numeric_value: number;
}

interface ClientDef {
  name: string;
  story: string;
}

interface Slot {
  index: number;
  card?: string | null;
  text?: string | null;
}

interface GameState {
  client: { name: string; age?: number; situation: string } | null;
  slots: Slot[];
}

const SLOT_LABELS = ["Slot 1", "Slot 2", "Slot 3"];

const EMPTY_SLOTS: Slot[] = [0, 1, 2].map((i) => ({ index: i, card: null, text: null }));

function cardDisplayName(name: string): string {
  return name.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

export default function PlayPage() {
  const [cards, setCards] = useState<CardDef[]>([]);
  const [clients, setClients] = useState<ClientDef[]>([]);
  const [loading, setLoading] = useState(true);

  const [customClient, setCustomClient] = useState(false);
  const [selectedClientName, setSelectedClientName] = useState("");
  const [customName, setCustomName] = useState("");
  const [customAge, setCustomAge] = useState("");
  const [customSituation, setCustomSituation] = useState("");

  const [slots, setSlots] = useState<Slot[]>(EMPTY_SLOTS);
  const [generating, setGenerating] = useState(false);
  const [lastResponse, setLastResponse] = useState<string>("");
  const [error, setError] = useState<string>("");

  useEffect(() => {
    Promise.all([
      fetch("/api/cards").then((r) => r.json()),
      fetch("/api/clients").then((r) => r.json()),
    ]).then(([c, cl]) => {
      setCards(c);
      setClients(cl);
      if (cl.length > 0) setSelectedClientName(cl[0].name);
      setLoading(false);
    });
  }, []);

  const activeClient = customClient
    ? { name: customName, age: customAge ? parseInt(customAge) : undefined, situation: customSituation }
    : clients.find((c) => c.name === selectedClientName)
      ? {
          name: selectedClientName,
          situation: clients.find((c) => c.name === selectedClientName)!.story,
        }
      : null;

  const nextEmptySlotIndex = slots.findIndex(
    (s) => s.card === null || s.card === undefined || s.card === ""
  );
  const targetSlotIndex = slots.findIndex(
    (s) => s.card && (s.text === null || s.text === undefined || s.text === "")
  );
  const isComplete = slots.every((s) => s.text);

  function setSlotCard(index: number, card: string) {
    setSlots((prev) => prev.map((s, i) => (i === index ? { ...s, card } : s)));
  }

  function clearSlotCard(index: number) {
    setSlots((prev) =>
      prev.map((s, i) => (i === index ? { ...s, card: null, text: null } : s))
    );
  }

  async function generate() {
    if (!activeClient || !activeClient.situation) {
      setError("Client situation is required.");
      return;
    }
    setError("");
    setGenerating(true);

    const body: GameState = { client: activeClient, slots };

    try {
      const res = await fetch("/api/reading", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error || "Unknown error");
        return;
      }
      setSlots(data.slots);
      setLastResponse(JSON.stringify(data, null, 2));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Request failed");
    } finally {
      setGenerating(false);
    }
  }

  function reset() {
    setSlots(EMPTY_SLOTS);
    setLastResponse("");
    setError("");
  }

  const requestPreview = activeClient
    ? JSON.stringify({ client: activeClient, slots }, null, 2)
    : "";

  if (loading) {
    return (
      <div className="min-h-screen bg-zinc-950 text-zinc-400 flex items-center justify-center font-mono text-sm">
        Loading...
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100 font-mono p-6">
      <div className="max-w-6xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-xl font-bold text-zinc-100">Tarot Debug</h1>
            <p className="text-xs text-zinc-500 mt-0.5">
              <a href="/" className="hover:text-zinc-300 transition-colors">← API docs</a>
            </p>
          </div>
          <button
            onClick={reset}
            className="text-xs text-zinc-500 hover:text-zinc-300 border border-zinc-700 hover:border-zinc-500 px-3 py-1.5 rounded transition-colors"
          >
            Reset
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Left: game controls */}
          <div className="space-y-5">
            {/* Client selector */}
            <section className="bg-zinc-900 border border-zinc-800 rounded p-4">
              <h2 className="text-xs font-semibold text-zinc-400 uppercase tracking-widest mb-3">Client</h2>

              <div className="flex gap-3 mb-3">
                <button
                  onClick={() => setCustomClient(false)}
                  className={`text-xs px-3 py-1.5 rounded border transition-colors ${
                    !customClient
                      ? "bg-zinc-700 border-zinc-600 text-zinc-100"
                      : "border-zinc-700 text-zinc-400 hover:border-zinc-600"
                  }`}
                >
                  Preset
                </button>
                <button
                  onClick={() => setCustomClient(true)}
                  className={`text-xs px-3 py-1.5 rounded border transition-colors ${
                    customClient
                      ? "bg-zinc-700 border-zinc-600 text-zinc-100"
                      : "border-zinc-700 text-zinc-400 hover:border-zinc-600"
                  }`}
                >
                  Custom
                </button>
              </div>

              {!customClient ? (
                <select
                  value={selectedClientName}
                  onChange={(e) => setSelectedClientName(e.target.value)}
                  className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-sm text-zinc-100 focus:outline-none focus:border-zinc-500"
                >
                  {clients.map((c) => (
                    <option key={c.name} value={c.name}>{c.name}</option>
                  ))}
                </select>
              ) : (
                <div className="space-y-2">
                  <input
                    type="text"
                    placeholder="Name"
                    value={customName}
                    onChange={(e) => setCustomName(e.target.value)}
                    className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-zinc-500"
                  />
                  <input
                    type="number"
                    placeholder="Age (optional)"
                    value={customAge}
                    onChange={(e) => setCustomAge(e.target.value)}
                    className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-zinc-500"
                  />
                  <textarea
                    placeholder="Situation (required) — who they are and what's happening"
                    value={customSituation}
                    onChange={(e) => setCustomSituation(e.target.value)}
                    rows={3}
                    className="w-full bg-zinc-800 border border-zinc-700 rounded px-3 py-2 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-zinc-500 resize-none"
                  />
                </div>
              )}

              {activeClient && !customClient && (
                <p className="mt-2 text-xs text-zinc-500 line-clamp-2">
                  {clients.find((c) => c.name === selectedClientName)?.story.slice(0, 120)}...
                </p>
              )}
            </section>

            {/* Slots */}
            <section className="bg-zinc-900 border border-zinc-800 rounded p-4">
              <h2 className="text-xs font-semibold text-zinc-400 uppercase tracking-widest mb-3">Cards</h2>

              <div className="space-y-4">
                {slots.map((slot, i) => {
                  const isNextEmpty = i === nextEmptySlotIndex;
                  const isTarget = i === targetSlotIndex;
                  const isFilled = !!slot.text;

                  return (
                    <div key={i} className={`rounded border p-3 ${
                      isFilled
                        ? "border-emerald-800 bg-emerald-950/30"
                        : isTarget
                        ? "border-amber-700 bg-amber-950/20"
                        : isNextEmpty
                        ? "border-zinc-600"
                        : "border-zinc-800 opacity-50"
                    }`}>
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-xs font-semibold text-zinc-400 uppercase tracking-wider">
                          {SLOT_LABELS[i]}
                        </span>
                        {isFilled && (
                          <span className="text-xs text-emerald-500">✓</span>
                        )}
                        {isTarget && (
                          <span className="text-xs text-amber-500">ready to generate</span>
                        )}
                      </div>

                      <div className="flex gap-2">
                        <select
                          value={slot.card ?? ""}
                          onChange={(e) => setSlotCard(i, e.target.value)}
                          disabled={isFilled || (!isNextEmpty && !slot.card)}
                          className="flex-1 bg-zinc-800 border border-zinc-700 rounded px-2 py-1.5 text-xs text-zinc-100 focus:outline-none focus:border-zinc-500 disabled:opacity-40 disabled:cursor-not-allowed"
                        >
                          <option value="">— pick a card —</option>
                          <optgroup label="Major Arcana">
                            {cards
                              .filter((c) => c.arcana === "major")
                              .map((c) => (
                                <option key={c.name} value={c.name}>
                                  {cardDisplayName(c.name)}
                                </option>
                              ))}
                          </optgroup>
                          {["cups", "gold", "swords", "wands"].map((suit) => (
                            <optgroup key={suit} label={suit.charAt(0).toUpperCase() + suit.slice(1)}>
                              {cards
                                .filter((c) => c.suit === suit)
                                .map((c) => (
                                  <option key={c.name} value={c.name}>
                                    {cardDisplayName(c.name)}
                                  </option>
                                ))}
                            </optgroup>
                          ))}
                        </select>

                        {slot.card && !isFilled && (
                          <button
                            onClick={() => clearSlotCard(i)}
                            className="text-xs text-zinc-500 hover:text-zinc-300 px-2"
                          >
                            ✕
                          </button>
                        )}
                      </div>

                      {slot.text && (
                        <p className="mt-2 text-sm text-zinc-200 leading-relaxed">
                          {slot.text}
                        </p>
                      )}
                    </div>
                  );
                })}
              </div>
            </section>

            {/* Generate / status */}
            <div className="space-y-2">
              {error && (
                <p className="text-xs text-red-400 bg-red-950/30 border border-red-800 rounded px-3 py-2">
                  {error}
                </p>
              )}

              {isComplete ? (
                <div className="text-xs text-emerald-400 bg-emerald-950/30 border border-emerald-800 rounded px-3 py-2">
                  Reading complete. Reset to start a new session.
                </div>
              ) : targetSlotIndex !== -1 ? (
                <button
                  onClick={generate}
                  disabled={generating || !activeClient?.situation}
                  className="w-full bg-zinc-100 text-zinc-900 hover:bg-white disabled:bg-zinc-700 disabled:text-zinc-400 rounded px-4 py-2.5 text-sm font-semibold transition-colors"
                >
                  {generating ? "Generating..." : "Generate Reading"}
                </button>
              ) : nextEmptySlotIndex !== -1 ? (
                <p className="text-xs text-zinc-500 text-center py-2">
                  Pick a card for {SLOT_LABELS[nextEmptySlotIndex]} to continue.
                </p>
              ) : null}
            </div>
          </div>

          {/* Right: JSON panels */}
          <div className="space-y-5">
            <section className="bg-zinc-900 border border-zinc-800 rounded p-4">
              <h2 className="text-xs font-semibold text-zinc-400 uppercase tracking-widest mb-3">
                Request Body
              </h2>
              <pre className="text-xs text-zinc-300 overflow-auto max-h-80 whitespace-pre-wrap leading-relaxed">
                {requestPreview || <span className="text-zinc-600">Select a client to see the request</span>}
              </pre>
            </section>

            {lastResponse && (
              <section className="bg-zinc-900 border border-zinc-800 rounded p-4">
                <h2 className="text-xs font-semibold text-zinc-400 uppercase tracking-widest mb-3">
                  Last Response
                </h2>
                <pre className="text-xs text-zinc-300 overflow-auto max-h-80 whitespace-pre-wrap leading-relaxed">
                  {lastResponse}
                </pre>
              </section>
            )}

            <section className="bg-zinc-900 border border-zinc-800 rounded p-4">
              <h2 className="text-xs font-semibold text-zinc-400 uppercase tracking-widest mb-2">Curl</h2>
              <pre className="text-xs text-zinc-400 overflow-auto whitespace-pre-wrap leading-relaxed">
                {`curl -X POST ${typeof window !== "undefined" ? window.location.origin : "http://localhost:3000"}/api/reading \\
  -H 'Content-Type: application/json' \\
  -d '${requestPreview.replace(/'/g, "'\\''")}'`}
              </pre>
            </section>
          </div>
        </div>
      </div>
    </div>
  );
}
