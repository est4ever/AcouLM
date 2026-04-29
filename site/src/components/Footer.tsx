export function Footer() {
  return (
    <footer className="border-t border-line py-8">
      <div className="mx-auto flex max-w-6xl flex-col gap-2 px-4 text-sm text-slate-400 sm:px-6 lg:px-8">
        <p>AcouLM is a local AI control plane for Windows.</p>
        <p className="flex flex-wrap gap-4">
          <a href="https://github.com/est4ever/AcouLM" target="_blank" rel="noreferrer" className="text-accent underline">GitHub</a>
          <span>MIT License</span>
          <a href="https://est4ever.github.io/AcouLM/" target="_blank" rel="noreferrer" className="text-accent underline">Website</a>
        </p>
      </div>
    </footer>
  );
}
