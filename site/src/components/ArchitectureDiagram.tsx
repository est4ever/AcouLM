function Node({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <div className="rounded-lg border border-line bg-panel p-4 shadow-glow">
      <p className="text-sm font-semibold text-slate-100">{title}</p>
      <p className="mt-1 font-mono text-xs text-slate-400">{subtitle}</p>
    </div>
  );
}

export function ArchitectureDiagram({ compact = false }: { compact?: boolean }) {
  return (
    <section id={compact ? undefined : "architecture"} className={compact ? "" : "section-wrap"}>
      {!compact && <h2 className="section-title">Architecture</h2>}
      {!compact && (
        <p className="section-subtitle">
          Browser and terminal clients share the same local HTTP surface and route into built-in and external inference runtimes.
        </p>
      )}
      <div className="mt-6 grid gap-4 lg:grid-cols-3">
        <Node title="Browser App Shell" subtitle="localhost:5173" />
        <Node title="HTTP API" subtitle="localhost:8000/v1" />
        <Node title="Backend Runtime" subtitle="npu_wrapper / external backend\nCPU / GPU / NPU" />
        <Node title="Terminal CLI" subtitle="npu_cli.ps1" />
      </div>
      <svg viewBox="0 0 1000 200" className="mt-6 w-full" aria-label="AcouLM data flow diagram">
        <defs>
          <marker id="arrowhead" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
            <polygon points="0,0 8,4 0,8" fill="#00d4ff" />
          </marker>
        </defs>
        <path d="M120 62 L420 62" stroke="#00d4ff" strokeWidth="2" markerEnd="url(#arrowhead)" fill="none" />
        <path d="M580 62 L880 62" stroke="#00d4ff" strokeWidth="2" markerEnd="url(#arrowhead)" fill="none" />
        <path d="M120 150 L420 84" stroke="#6b7cff" strokeWidth="2" markerEnd="url(#arrowhead)" fill="none" />
        <path d="M880 84 L880 150" stroke="#00d4ff" strokeWidth="2" markerEnd="url(#arrowhead)" fill="none" />
        <text x="240" y="48" fill="#9ca3af" fontSize="14">Browser UI -&gt; API Layer</text>
        <text x="666" y="48" fill="#9ca3af" fontSize="14">API Layer -&gt; Backend Runtime</text>
        <text x="215" y="165" fill="#9ca3af" fontSize="14">CLI: npu_cli.ps1 -&gt; API</text>
        <text x="812" y="172" fill="#9ca3af" fontSize="14">CPU | GPU | NPU</text>
      </svg>
    </section>
  );
}
