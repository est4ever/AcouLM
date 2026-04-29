module.exports = {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        page: "#0a0a0a",
        panel: "#111318",
        line: "#2a2f3a",
        accent: "#00d4ff"
      },
      boxShadow: {
        glow: "0 0 0 1px rgba(0,212,255,0.35), 0 0 24px rgba(0,212,255,0.16), 0 0 42px rgba(139,92,246,0.12)"
      }
    }
  },
  plugins: []
};
