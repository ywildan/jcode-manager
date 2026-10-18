"use client";

import {
  Component,
  useCallback,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import dynamic from "next/dynamic";
import { toast } from "sonner";
import {
  ArrowDown,
  ArrowUpRight,
  Menu,
  ToggleLeft,
  ToggleRight,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetTitle,
} from "@/components/ui/sheet";
import { Progress } from "@/components/ui/progress";
import { MotionSetup } from "@/components/motion";
import {
  ChecksPlate,
  CommandsPlate,
  EnginesPlate,
  FaqPlate,
  FilePlate,
  InstallPlate,
  LaunchPlate,
  MenuPlate,
  OutroPlate,
  SafetyPlate,
  StudioPlate,
} from "@/components/plates";
import { brand, heroMeta, stats, ticker } from "@/lib/content";
import { initialLoad, type LoadState } from "@/lib/scene";

const plateList = [
  { id: "deck", name: "The deck" },
  { id: "numbers", name: "By the numbers" },
  { id: "problem", name: "The file" },
  { id: "menu", name: "The menu" },
  { id: "launch", name: "The launch" },
  { id: "studio", name: "Studio" },
  { id: "safety", name: "Safety" },
  { id: "install", name: "Install" },
  { id: "commands", name: "Commands" },
  { id: "engines", name: "Engines" },
  { id: "checks", name: "Checks" },
  { id: "faq", name: "Questions" },
];

function Still({ onLoad }: { onLoad: (value: LoadState) => void }) {
  useEffect(
    () =>
      onLoad({
        status: "fallback",
        progress: 100,
        stage: "A still view of the deck",
      }),
    [onLoad],
  );
  return null;
}

const World = dynamic(
  () => import("./scene").then((module) => module.Scene).catch(() => Still),
  { ssr: false },
);

class DeckBoundary extends Component<
  { children: ReactNode; onFailure: () => void },
  { failed: boolean }
> {
  state = { failed: false };
  static getDerivedStateFromError() {
    return { failed: true };
  }
  componentDidCatch() {
    this.props.onFailure();
  }
  render() {
    return this.state.failed ? null : this.props.children;
  }
}

export function Landing() {
  const [load, setLoad] = useState(initialLoad);
  const [fonts, setFonts] = useState(false);
  const [entered, setEntered] = useState(false);
  const [revealing, setRevealing] = useState(false);
  const [still, setStill] = useState(false);
  const [slow, setSlow] = useState(false);
  const [paused, setPaused] = useState(false);
  const [notes, setNotes] = useState(false);
  const [active, setActive] = useState(true);
  const [plate, setPlate] = useState(0);
  const progress = useRef(0);
  const shell = useRef<HTMLDivElement>(null);
  const accepted = useRef(false);
  const currentPlate = useRef(0);

  const onLoad = useCallback((next: LoadState) => {
    if (!accepted.current) setLoad(next);
  }, []);

  const useStill = useCallback(() => {
    accepted.current = true;
    setStill(true);
    setFonts(true);
    setLoad({
      status: "fallback",
      progress: 100,
      stage: "A still view of the deck",
    });
  }, []);

  const onScroll = useCallback((viewportHeights: number) => {
    progress.current = viewportHeights;
    let next = 0;
    for (let index = 0; index < plateList.length; index++) {
      const node = document.getElementById(plateList[index].id);
      if (node && node.getBoundingClientRect().top <= innerHeight * 0.42) {
        next = index;
      }
    }
    if (currentPlate.current !== next) {
      currentPlate.current = next;
      setPlate(next);
    }
  }, []);

  useEffect(() => {
    let alive = true;
    document.fonts.ready
      .then(() => {
        if (alive) setFonts(true);
      })
      .catch(() => {
        if (alive) setFonts(true);
      });
    const timeout = setTimeout(() => {
      if (alive) setSlow(true);
    }, 9000);
    const motion = matchMedia("(prefers-reduced-motion: reduce)");
    const sync = () => setPaused(motion.matches);
    sync();
    motion.addEventListener("change", sync);
    return () => {
      alive = false;
      clearTimeout(timeout);
      motion.removeEventListener("change", sync);
    };
  }, []);

  useEffect(() => {
    if (load.status === "loading" || !fonts) return;
    setRevealing(true);
    const timer = setTimeout(() => setEntered(true), paused ? 0 : 720);
    return () => clearTimeout(timer);
  }, [load.status, fonts, paused]);

  useEffect(() => {
    if (entered) return;
    const previous = document.documentElement.style.overflow;
    document.documentElement.style.overflow = "hidden";
    return () => {
      document.documentElement.style.overflow = previous;
    };
  }, [entered]);

  useEffect(() => {
    document.documentElement.classList.toggle("motion-off", paused);
    return () => document.documentElement.classList.remove("motion-off");
  }, [paused]);

  useEffect(() => {
    const observer = new IntersectionObserver(([entry]) =>
      setActive(entry.isIntersecting),
    );
    if (shell.current) observer.observe(shell.current);
    return () => observer.disconnect();
  }, []);

  const pendingGo = useRef<number | null>(null);

  const scrollTo = (index: number) => {
    document.getElementById(plateList[index].id)?.scrollIntoView({
      behavior: paused ? "auto" : "smooth",
      block: "start",
    });
  };

  const go = (index: number) => {
    if (notes) {
      // The sheet holds the page still; move once it has finished closing.
      pendingGo.current = index;
      setNotes(false);
      return;
    }
    scrollTo(index);
  };

  useEffect(() => {
    if (notes || pendingGo.current === null) return;
    const index = pendingGo.current;
    pendingGo.current = null;
    const timer = setTimeout(() => scrollTo(index), 460);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [notes]);

  const toggleMotion = () => {
    const next = !paused;
    setPaused(next);
    toast(
      next ? "Ambient animations off" : "Ambient animations on",
      {
        id: "motion",
        description: next
          ? "The deck holds still. Everything else still works."
          : "The constellation is moving again.",
        icon: next ? <ToggleLeft size={18} /> : <ToggleRight size={18} />,
      },
    );
  };

  const percent = Math.min(
    100,
    Math.round(load.progress * 0.9 + (fonts ? 10 : 0)),
  );

  return (
    <>
      <div className="deck" aria-hidden="true" data-state={load.status}>
        <div className="still-deck">
          <div className="still-ring still-ring-a" />
          <div className="still-ring still-ring-b" />
          <div className="still-ring still-ring-c" />
          <div className="still-core" />
        </div>
        {!still && (
          <DeckBoundary onFailure={useStill}>
            <World
              progress={progress}
              paused={paused}
              active={active && !notes}
              onLoad={onLoad}
            />
          </DeckBoundary>
        )}
        <div className="deck-grid" />
        <div className="deck-vignette" />
      </div>

      {!entered && (
        <div
          className="curtain"
          data-leaving={revealing}
          role="status"
          aria-live="polite"
          aria-label="Preparing the deck"
        >
          <div className="curtain-meta">
            <span>JCODE MANAGER</span>
            <span>{brand.version}</span>
          </div>
          <div className="curtain-mid">
            <div className="curtain-glyph" aria-hidden="true">
              <i />
              <i />
              <i />
              <span />
            </div>
            <div className="curtain-copy">
              <span className="eyebrow">Reading the provider registry</span>
              <p>
                A black room.
                <br />
                <span>Nine switches.</span>
              </p>
            </div>
          </div>
          <div className="curtain-foot">
            <div className="curtain-status">
              <span>
                {load.progress === 100 && !fonts ? "Setting the type" : load.stage}
              </span>
              <span aria-hidden="true">
                {String(percent).padStart(3, "0")}
                <small> / 100</small>
              </span>
            </div>
            <Progress
              value={percent}
              locale="en-US"
              aria-label="Deck preparation"
            />
            {slow && (
              <Button
                variant="ghost"
                className="curtain-skip"
                onClick={useStill}
              >
                Continue with the still view <ArrowUpRight size={15} />
              </Button>
            )}
          </div>
        </div>
      )}

      <div
        className="shell"
        data-entered={entered || revealing}
        inert={revealing && !entered}
        ref={shell}
      >
        <header className="deck-header">
          <a className="wordmark" href="#deck" aria-label="Jcode Manager, top">
            <span className="wordmark-glyph" aria-hidden="true" />
            <b>JCODE MANAGER</b>
            <small>{brand.version}</small>
          </a>
          <span className="header-tag">
            <i />
            {brand.label}
          </span>
          <div className="header-actions">
            <Button
              variant="ghost"
              className="motion-toggle"
              onClick={toggleMotion}
              aria-pressed={!paused}
              aria-label="Ambient animations"
              aria-description="Controls automatic movement only. Scroll and every control keep working."
              title={
                paused
                  ? "Enable ambient animations"
                  : "Disable ambient animations"
              }
            >
              {paused ? (
                <ToggleLeft size={18} aria-hidden="true" />
              ) : (
                <ToggleRight size={18} aria-hidden="true" />
              )}
            </Button>
            <Button
              variant="ghost"
              className="menu-toggle"
              onClick={() => setNotes(true)}
            >
              <span>Plate map</span>
              <Menu size={18} aria-hidden="true" />
            </Button>
          </div>
        </header>

        <div className="rail-progress" aria-hidden="true" />

        <MotionSetup onScroll={onScroll} />

        <main id="main">
          <section className="plate hero" id="deck" aria-labelledby="hero-title">
            <div className="rail hero-inner">
              <div className="hero-copy">
                <span className="eyebrow">
                  <span className="tick" />
                  An interactive manager for jcode CLI providers
                </span>
                <h1 id="hero-title">
                  EVERY PROVIDER.
                  <br />
                  <em>ONE MENU.</em>
                </h1>
                <p className="lede hero-lede">
                  jcode talks to any OpenAI-compatible endpoint, once a provider
                  profile exists in ~/.jcode/config.toml. Jcode Manager turns that
                  file into a menu: add, list, edit, delete, quick-start, generate,
                  launch, restore. Nothing to install, nothing to remember.
                </p>
                <div className="hero-actions">
                  <Button
                    className="cta"
                    nativeButton={false}
                    render={<a href="#install" />}
                  >
                    <span>Install in one command</span>
                    <span className="cta-orbit">
                      <ArrowDown size={18} aria-hidden="true" />
                    </span>
                  </Button>
                  <Button
                    variant="outline"
                    className="cta-ghost"
                    nativeButton={false}
                    render={<a href="#commands" />}
                  >
                    See every command
                    <ArrowUpRight size={17} aria-hidden="true" />
                  </Button>
                </div>
                <ul className="hero-meta">
                  {heroMeta.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              </div>

              <aside className="hero-figure" data-drift>
                <div className="fig-tag">
                  <span>FIG. 001</span>
                  <i />
                  <span>
                    Nine operations
                    <br />
                    zero hand-edited TOML
                  </span>
                </div>
                <div className="readout">
                  <div className="readout-row">
                    <span>Engines</span>
                    <strong className="sig">Python 3.8+ / bash</strong>
                  </div>
                  <div className="readout-row">
                    <span>Config</span>
                    <strong>~/.jcode/config.toml</strong>
                  </div>
                  <div className="readout-row">
                    <span>Platforms</span>
                    <strong>Linux · macOS · Windows</strong>
                  </div>
                  <div className="readout-row">
                    <span>Backups</span>
                    <strong>before every write</strong>
                  </div>
                  <div className="readout-row">
                    <span>Checks</span>
                    <strong className="sig">157 passing</strong>
                  </div>
                </div>
              </aside>
            </div>
            <div className="rail hero-foot">
              <span>
                Nothing to rush.
                <br />
                Everything backed up.
              </span>
              <span className="hero-scroll">
                Scroll to open the deck <ArrowDown size={14} aria-hidden="true" />
              </span>
              <span>
                {brand.version} · MIT
              </span>
            </div>
          </section>

          <div className="ticker">
            <p className="sr-only">{ticker.join(" · ")}</p>
            <div className="ticker-track" aria-hidden="true">
              {[0, 1].map((copy) => (
                <div className="ticker-group" key={copy}>
                  {ticker.map((item) => (
                    <span key={item}>
                      {item}
                      <span className="ticker-sep" />
                    </span>
                  ))}
                </div>
              ))}
            </div>
          </div>

          <section className="plate" id="numbers">
            <div className="rail plate-inner">
              <div className="stat-grid">
                {stats.map((item) => (
                  <article className="stat" key={item.label}>
                    <b>{item.value}</b>
                    <strong>{item.label}</strong>
                    <p>{item.detail}</p>
                  </article>
                ))}
              </div>
            </div>
          </section>

          <FilePlate />
          <MenuPlate />
          <LaunchPlate />
          <StudioPlate />
          <SafetyPlate />
          <InstallPlate />
          <CommandsPlate />
          <EnginesPlate />
          <ChecksPlate />
          <FaqPlate />
          <OutroPlate />
        </main>

        <nav className="plate-nav" aria-label="Plates">
          {plateList.map((item, index) => (
            <Button
              key={item.id}
              variant="unstyled"
              className="plate-dot"
              aria-current={plate === index ? "true" : undefined}
              onClick={() => go(index)}
            >
              <i />
              <span>
                {String(index + 1).padStart(2, "0")} {item.name}
              </span>
            </Button>
          ))}
        </nav>

        <footer className="deck-footer">
          <div className="rail footer-grid">
            <div className="footer-brand">
              <a className="wordmark" href="#deck">
                <span className="wordmark-glyph" aria-hidden="true" />
                <b>JCODE MANAGER</b>
                <small>{brand.version}</small>
              </a>
              <p>{brand.summary}</p>
            </div>
            <div className="footer-col">
              <h4>On this page</h4>
              <ul>
                <li>
                  <a href="#problem">The config file</a>
                </li>
                <li>
                  <a href="#menu">The nine operations</a>
                </li>
                <li>
                  <a href="#launch">The daemon</a>
                </li>
                <li>
                  <a href="#studio">Provider studio</a>
                </li>
                <li>
                  <a href="#safety">Safety</a>
                </li>
              </ul>
            </div>
            <div className="footer-col">
              <h4>Reference</h4>
              <ul>
                <li>
                  <a href="#install">Install</a>
                </li>
                <li>
                  <a href="#commands">Non-interactive flags</a>
                </li>
                <li>
                  <a href="#engines">Engines &amp; paths</a>
                </li>
                <li>
                  <a href="#checks">Testing</a>
                </li>
                <li>
                  <a href="#faq">Questions</a>
                </li>
              </ul>
            </div>
            <div className="footer-col">
              <h4>Keep in mind</h4>
              <ul>
                <li>
                  <span>Documentation ships in the folder: README.md (English) and README.id.md (Indonesian).</span>
                </li>
                <li>
                  <span>No accounts, no trackers, no cookies, nothing submitted.</span>
                </li>
                <li>
                  <span>
                    Manages the config only. Creating an API key stays with your
                    provider.
                  </span>
                </li>
              </ul>
            </div>
          </div>
          <div className="rail footer-base">
            <span>
              © 2026 Jcode Manager · MIT. Design adapted from LN&rsquo;s
              landing-page collection (MIT, lndev.me).
            </span>
            <button type="button" className="text-action" onClick={toggleMotion}>
              {paused ? "Turn animations on" : "Turn animations off"}
            </button>
            <button
              type="button"
              className="text-action"
              onClick={() => go(0)}
            >
              Back to the top <ArrowUpRight size={15} aria-hidden="true" />
            </button>
          </div>
        </footer>

        <Sheet open={notes} onOpenChange={setNotes}>
          <SheetContent className="plate-map">
            <span className="eyebrow">
              <span className="tick" />
              The plate map
            </span>
            <SheetTitle>
              A map of the deck,
              <br />
              start to finish.
            </SheetTitle>
            <SheetDescription>
              Jump anywhere. The constellation behind you is drawn live with
              Three.js and falls back to a still frame when a GPU is not
              available. Turn ambient animations off whenever you like.
            </SheetDescription>
            <nav className="sheet-nav" aria-label="Jump to a plate">
              {plateList.map((item, index) => (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => go(index)}
                  aria-current={plate === index ? "true" : undefined}
                >
                  <span>{String(index + 1).padStart(2, "0")}</span>
                  {item.name}
                  <ArrowUpRight size={16} aria-hidden="true" />
                </button>
              ))}
            </nav>
            <div className="sheet-block">
              <h3>What this page is</h3>
              <p>
                The landing page for Jcode Manager, a plain-file CLI tool. It
                demonstrates the menu, the launch order and the safety rails. The
                provider studio writes nothing, stores nothing and never asks for a
                key.
              </p>
            </div>
            <div className="sheet-block">
              <h3>Accessibility</h3>
              <p>
                Every control is a real button or link, focus stays visible, the
                terminal replay is available as static text for screen readers, and
                a reduced-motion preference is respected live.
              </p>
            </div>
            <Button variant="outline" onClick={toggleMotion}>
              {paused ? (
                <ToggleLeft size={18} aria-hidden="true" />
              ) : (
                <ToggleRight size={18} aria-hidden="true" />
              )}
              {paused ? "Enable ambient animations" : "Disable ambient animations"}
            </Button>
          </SheetContent>
        </Sheet>
      </div>
    </>
  );
}
