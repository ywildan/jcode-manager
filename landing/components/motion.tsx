"use client";

import { useEffect } from "react";

/** Everything that staggers, drifts or tilts, in one coalesced scroll loop. */
export function MotionSetup({
  onScroll,
}: {
  onScroll?: (viewportHeights: number) => void;
}) {
  useEffect(() => {
    const reduce = matchMedia("(prefers-reduced-motion: reduce)");
    const fine = matchMedia("(hover: hover) and (pointer: fine)");
    let dispose = () => {};

    const start = () => {
      dispose();
      const root = document.documentElement;

      /* ---- Scroll, coalesced into a single frame ------------------ */
      let frame = 0;
      const update = () => {
        frame = 0;
        const available = root.scrollHeight - innerHeight;
        const progress = available > 0 ? scrollY / available : 0;
        root.style.setProperty("--page-progress", String(progress));
        onScroll?.(scrollY / Math.max(1, innerHeight));
        layers.forEach((layer) => {
          const rect = layer.getBoundingClientRect();
          // -1 above the fold, +1 below; the layer drifts against the scroll.
          const local = Math.max(
            -1,
            Math.min(
              1,
              (innerHeight / 2 - rect.top - rect.height / 2) /
                (innerHeight / 2 + rect.height / 2),
            ),
          );
          layer.style.setProperty("--drift", `${local * 34}px`);
        });
        // A safety net for the observer: anything already on screen is shown.
        if (pending.size) {
          pending.forEach((node) => {
            const rect = node.getBoundingClientRect();
            if (rect.top < innerHeight * 0.94 && rect.bottom > 0) {
              node.classList.add("motion-in");
              pending.delete(node);
            }
          });
        }
      };
      const schedule = () => {
        if (!frame) frame = requestAnimationFrame(update);
      };

      const layers = Array.from(
        document.querySelectorAll<HTMLElement>("[data-drift]"),
      );

      /* ---- Entrances --------------------------------------------- */
      const pending = new Set<HTMLElement>();
      const selector = [
        "[data-reveal] > *",
        ".stat",
        ".menu-card",
        ".safety-card",
        ".check",
        ".install-card",
        ".engine-card",
        ".gotcha",
        ".flow-step",
        ".cli-group",
        ".env-row",
        ".faq-item",
        ".slab",
        ".table-wrap",
        ".outro-actions",
      ].join(",");
      const targets = Array.from(
        document.querySelectorAll<HTMLElement>(selector),
      );

      const media = reduce.matches;
      const observer =
        !media && "IntersectionObserver" in window
          ? new IntersectionObserver(
              (entries) => {
                entries.forEach(({ target, isIntersecting }) => {
                  if (!isIntersecting) return;
                  target.classList.add("motion-in");
                  pending.delete(target as HTMLElement);
                  observer?.unobserve(target);
                });
              },
              { threshold: 0.1, rootMargin: "0px 0px -40px 0px" },
            )
          : null;

      if (observer) {
        targets.forEach((node) => {
          // Never hide what the visitor may already be looking at.
          if (node.getBoundingClientRect().top < innerHeight * 0.9) return;
          const siblings = Array.from(node.parentElement?.children ?? []).filter(
            (child) => targets.includes(child as HTMLElement),
          );
          node.style.setProperty(
            "--reveal-delay",
            `${Math.min(Math.max(0, siblings.indexOf(node)), 4) * 70}ms`,
          );
          node.classList.add("motion-ready");
          pending.add(node);
          observer.observe(node);
        });
      }

      root.classList.add("motion-on");

      /* ---- A small physical response, precise pointers only ------- */
      const tilts = Array.from(
        document.querySelectorAll<HTMLElement>("[data-tilt]"),
      );
      const move = (event: PointerEvent) => {
        const node = event.currentTarget as HTMLElement;
        if (!fine.matches || event.pointerType === "touch") return;
        const rect = node.getBoundingClientRect();
        node.style.setProperty(
          "--tilt-y",
          `${((event.clientX - rect.left - rect.width / 2) / rect.width) * 2.6}deg`,
        );
        node.style.setProperty(
          "--tilt-x",
          `${(-(event.clientY - rect.top - rect.height / 2) / rect.height) * 2.6}deg`,
        );
      };
      const reset = (event: PointerEvent) => {
        const node = event.currentTarget as HTMLElement;
        node.style.removeProperty("--tilt-x");
        node.style.removeProperty("--tilt-y");
      };
      tilts.forEach((node) => {
        node.classList.add("motion-tilt");
        node.addEventListener("pointermove", move);
        node.addEventListener("pointerleave", reset);
      });

      addEventListener("scroll", schedule, { passive: true });
      addEventListener("resize", schedule);
      schedule();

      dispose = () => {
        cancelAnimationFrame(frame);
        observer?.disconnect();
        removeEventListener("scroll", schedule);
        removeEventListener("resize", schedule);
        root.classList.remove("motion-on");
        root.style.removeProperty("--page-progress");
        targets.forEach((node) => {
          node.classList.remove("motion-ready", "motion-in");
          node.style.removeProperty("--reveal-delay");
        });
        pending.clear();
        layers.forEach((node) => node.style.removeProperty("--drift"));
        tilts.forEach((node) => {
          node.classList.remove("motion-tilt");
          node.style.removeProperty("--tilt-x");
          node.style.removeProperty("--tilt-y");
          node.removeEventListener("pointermove", move);
          node.removeEventListener("pointerleave", reset);
        });
      };
    };

    start();
    reduce.addEventListener("change", start);
    return () => {
      dispose();
      reduce.removeEventListener("change", start);
    };
  }, [onScroll]);

  return null;
}
