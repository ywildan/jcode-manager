"use client";

import { useEffect, useRef, useState } from "react";
import { Play, RotateCcw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { replays, replayNotice } from "@/lib/replay";

/** Types the transcript out the way a terminal would, and stops when unwatched. */
export function Replay() {
  const [index, setIndex] = useState(0);
  const [progress, setProgress] = useState(0);
  const [typing, setTyping] = useState(0);
  const [playing, setPlaying] = useState(true);
  const [visible, setVisible] = useState(false);
  const [instant, setInstant] = useState(false);
  const screen = useRef<HTMLDivElement>(null);
  const host = useRef<HTMLDivElement>(null);

  const replay = replays[index];
  const total = replay.lines.length;

  useEffect(() => {
    const media = matchMedia("(prefers-reduced-motion: reduce)");
    const sync = () => setInstant(media.matches);
    sync();
    media.addEventListener("change", sync);
    return () => media.removeEventListener("change", sync);
  }, []);

  useEffect(() => {
    const node = host.current;
    if (!node) return;
    const observer = new IntersectionObserver(
      ([entry]) => setVisible(entry.isIntersecting),
      { threshold: 0.22 },
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  const restart = (next: number) => {
    setIndex(next);
    setProgress(0);
    setTyping(0);
    setPlaying(true);
  };

  useEffect(() => {
    if (instant) {
      setProgress(total);
      setPlaying(false);
    }
  }, [instant, total, index]);

  useEffect(() => {
    if (!playing || !visible || instant) return;
    if (progress >= total) {
      setPlaying(false);
      return;
    }
    const line = replay.lines[progress];
    const typed = Boolean(line.typed) && typing < line.text.length;
    if (typed) {
      const timer = setTimeout(() => setTyping((value) => value + 1), 16);
      return () => clearTimeout(timer);
    }
    const timer = setTimeout(
      () => {
        setProgress((value) => value + 1);
        setTyping(0);
      },
      line.text.length ? (line.typed ? 300 : 170) : 90,
    );
    return () => clearTimeout(timer);
  }, [playing, visible, instant, progress, typing, total, replay]);

  useEffect(() => {
    const node = screen.current;
    if (node) node.scrollTop = node.scrollHeight;
  }, [progress, typing]);

  const shown = replay.lines.slice(0, progress);
  const current = progress < total ? replay.lines[progress] : null;
  const partial = current?.typed ? current.text.slice(0, typing) : null;
  const done = progress >= total && !playing;

  return (
    <div className="replay" ref={host}>
      <div className="term" data-tilt>
        <div className="term-bar">
          <span className="term-lights" aria-hidden="true">
            <i />
            <i />
            <i />
          </span>
          <span>jcode-manager · tty</span>
          <span aria-hidden="true">
            {done ? "idle" : playing ? "running" : "paused"} · {replay.menu}/9
          </span>
        </div>
        <div className="term-screen" ref={screen} aria-hidden="true">
          {shown.map((line, position) => (
            <span className="term-line" data-tone={line.tone} key={position}>
              {line.text || "\u00A0"}
              {"\n"}
            </span>
          ))}
          {partial !== null ? (
            <span className="term-line" data-tone={current?.tone}>
              {partial}
              <span className="term-cur" />
              {"\n"}
            </span>
          ) : current ? (
            <span className="term-line" data-tone={current.tone}>
              <span className="term-cur" />
            </span>
          ) : (
            <span className="term-line" data-tone="ok">
              session complete.
            </span>
          )}
        </div>
        <pre className="sr-only">{`${replay.title}\n${replay.lines
          .map((line) => line.text)
          .join("\n")}`}</pre>
      </div>

      <div className="replay-side">
        <div className="term-key" role="group" aria-label="Replay an operation">
          {replays.map((item, position) => (
            <button
              key={item.id}
              type="button"
              aria-pressed={position === index}
              onClick={() => restart(position)}
            >
              {item.menu} · {item.title}
            </button>
          ))}
        </div>
        <div>
          <h3>{replay.title}</h3>
          <p className="mono-note" style={{ marginTop: 10 }}>
            {replay.caption}
          </p>
        </div>
        <div className="hero-actions" style={{ marginTop: 0 }}>
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              if (progress >= total) restart(index);
              else setPlaying((value) => !value);
            }}
          >
            {progress >= total ? (
              <>
                <RotateCcw size={14} aria-hidden="true" /> Replay this session
              </>
            ) : playing ? (
              <>Pause</>
            ) : (
              <>
                <Play size={14} aria-hidden="true" /> Continue
              </>
            )}
          </Button>
        </div>
        <p className="replay-note">{replayNotice}</p>
      </div>
    </div>
  );
}
