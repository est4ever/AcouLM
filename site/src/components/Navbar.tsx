import { navItems } from "../data/site";

export function Navbar() {
  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-line/70 bg-page/90 backdrop-blur">
      <nav className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3 sm:px-6 lg:px-8" aria-label="Main navigation">
        <a href="#top" className="text-lg font-semibold tracking-tight text-white">AcouLM</a>
        <ul className="hidden gap-5 text-sm text-slate-300 md:flex">
          {navItems.map((item) => (
            <li key={item.label}>
              <a
                href={item.href}
                target={item.external ? "_blank" : undefined}
                rel={item.external ? "noreferrer" : undefined}
                className={
                  item.cta
                    ? "rounded-md border border-accent/60 px-3 py-1.5 text-accent transition hover:bg-accent/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent"
                    : "transition hover:text-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent"
                }
              >
                {item.label}
              </a>
            </li>
          ))}
        </ul>
      </nav>
    </header>
  );
}
