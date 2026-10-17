"use client";
import { useEffect, useRef } from "react";
import type { MutableRefObject } from "react";
import { cameraAt, nodeLayout } from "@/lib/scene";
import type { LoadState } from "@/lib/scene";

type Props = {
  /** Scroll position in viewport heights. */
  progress: MutableRefObject<number>;
  /** Ambient animation off: the world renders one still frame. */
  paused: boolean;
  /** The deck is on screen. */
  active: boolean;
  onLoad: (value: LoadState) => void;
};

const SHELL = 5.3;
const NODES = 9;

/** A soft round dot, drawn once and reused by every sprite and particle. */
function dotTexture(T: typeof import("three")) {
  const size = 128;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");
  if (ctx) {
    const gradient = ctx.createRadialGradient(
      size / 2,
      size / 2,
      0,
      size / 2,
      size / 2,
      size / 2,
    );
    gradient.addColorStop(0, "rgba(255,255,255,1)");
    gradient.addColorStop(0.28, "rgba(247,247,244,0.74)");
    gradient.addColorStop(0.62, "rgba(205,205,199,0.16)");
    gradient.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, size, size);
  }
  const texture = new T.CanvasTexture(canvas);
  texture.colorSpace = T.SRGBColorSpace;
  return texture;
}

export function Scene(props: Props) {
  const host = useRef<HTMLDivElement>(null);
  const state = useRef(props);
  const draw = useRef(() => {});

  useEffect(() => {
    state.current = props;
  }, [props]);

  // Only a change of mood redraws: scroll lives in a ref, so it never re-renders.
  useEffect(() => {
    draw.current();
  }, [props.paused, props.active]);

  useEffect(() => {
    const element = host.current;
    if (!element) return;
    // Re-bound so the async setup below keeps the narrowing.
    const node = element;

    let disposed = false;
    let failed = false;
    let cleaned = false;
    let raf = 0;
    let clock = 0;
    let last = 0;
    let pointerX = 0;
    let pointerY = 0;
    let width = element.clientWidth || 1;
    let height = element.clientHeight || 1;

    const resources = new Set<{ dispose: () => void }>();
    const listeners: (() => void)[] = [];
    const frames = new Map<number, (alive: boolean) => void>();

    const own = <T extends { dispose: () => void }>(resource: T): T => {
      resources.add(resource);
      return resource;
    };
    const release = (resource: { dispose: () => void }) => {
      if (resources.delete(resource)) resource.dispose();
    };
    const cleanup = () => {
      if (cleaned) return;
      cleaned = true;
      draw.current = () => {};
      cancelAnimationFrame(raf);
      frames.forEach((resolve, id) => {
        cancelAnimationFrame(id);
        resolve(false);
      });
      frames.clear();
      listeners.reverse().forEach((off) => {
        try {
          off();
        } catch {}
      });
      listeners.length = 0;
      [...resources].reverse().forEach((item) => {
        try {
          item.dispose();
        } catch {}
      });
      resources.clear();
    };
    const fallback = () => {
      if (disposed || failed) return;
      failed = true;
      cleanup();
      state.current.onLoad({
        status: "fallback",
        progress: 100,
        stage: "A still view of the deck",
      });
    };

    const frame = () =>
      new Promise<boolean>((resolve) => {
        if (disposed || failed) {
          resolve(false);
          return;
        }
        const id = requestAnimationFrame(() => {
          frames.delete(id);
          resolve(!disposed && !failed);
        });
        frames.set(id, resolve);
      });
    const stage = async (progress: number, label: string) => {
      if (disposed || failed) return false;
      state.current.onLoad({ status: "loading", progress, stage: label });
      return (await frame()) && (await frame());
    };

    async function setup() {
      if (!(await stage(6, "Clearing the room"))) return;

      let T: typeof import("three");
      try {
        T = await import("three");
      } catch {
        fallback();
        return;
      }
      if (disposed || failed) return;

      const compact = width < 780;
      let renderer: import("three").WebGLRenderer;
      try {
        renderer = own(
          new T.WebGLRenderer({
            alpha: true,
            antialias: !compact,
            powerPreference: "high-performance",
          }),
        );
      } catch {
        fallback();
        return;
      }
      renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, compact ? 1.3 : 1.75));
      renderer.setSize(width, height);
      renderer.setClearColor(0x000000, 0);
      renderer.domElement.style.opacity = "0";
      renderer.domElement.style.transition = "opacity 900ms ease";
      renderer.domElement.className = "deck-canvas";
      node.appendChild(renderer.domElement);
      listeners.push(() => renderer.domElement.remove());

      const contextLost = (event: Event) => {
        event.preventDefault();
        fallback();
      };
      renderer.domElement.addEventListener("webglcontextlost", contextLost);
      listeners.push(() =>
        renderer.domElement.removeEventListener("webglcontextlost", contextLost),
      );

      const scene = new T.Scene();
      const camera = new T.PerspectiveCamera(
        compact ? 52 : 42,
        width / height,
        0.1,
        90,
      );
      camera.position.set(0, 0.6, 13.4);

      const glow = own(dotTexture(T));

      /* ---- The lattice the providers hang from ------------------- */
      const latticeGeometry = own(
        new T.WireframeGeometry(new T.IcosahedronGeometry(SHELL, 1)),
      );
      const latticeMaterial = own(
        new T.LineBasicMaterial({
          color: 0x555550,
          transparent: true,
          opacity: 0.3,
          depthWrite: false,
        }),
      );
      const lattice = new T.LineSegments(latticeGeometry, latticeMaterial);

      const shellGeometry = own(
        new T.BufferGeometry(),
      );
      const shellCount = compact ? 700 : 1500;
      const shellPositions = new Float32Array(shellCount * 3);
      for (let i = 0; i < shellCount; i++) {
        const u = Math.random() * 2 - 1;
        const theta = Math.random() * Math.PI * 2;
        const r = Math.sqrt(1 - u * u);
        // A shell, not a ball: the emptiness in the middle belongs to the core.
        const radius = SHELL + (Math.random() - 0.5) * 0.5;
        shellPositions[i * 3] = Math.cos(theta) * r * radius;
        shellPositions[i * 3 + 1] = u * radius * 0.94;
        shellPositions[i * 3 + 2] = Math.sin(theta) * r * radius;
      }
      shellGeometry.setAttribute(
        "position",
        new T.BufferAttribute(shellPositions, 3),
      );
      const shellMaterial = own(
        new T.PointsMaterial({
          size: 0.075,
          map: glow,
          color: 0xe4e4df,
          transparent: true,
          opacity: 0.4,
          depthWrite: false,
          blending: T.AdditiveBlending,
          sizeAttenuation: true,
        }),
      );
      const shell = new T.Points(shellGeometry, shellMaterial);

      const world = new T.Group();
      world.add(lattice, shell);

      /* ---- Instrument rings -------------------------------------- */
      const rings: import("three").Mesh[] = [];
      const ringConfig = [
        { radius: SHELL * 1.02, tilt: 1.42, opacity: 0.3, z: 0.36 },
        { radius: SHELL * 0.74, tilt: 0.42, opacity: 0.2, z: -0.9 },
        { radius: SHELL * 1.28, tilt: 2.05, opacity: 0.13, z: 0.62 },
      ];
      ringConfig.forEach((config) => {
        const geometry = own(
          new T.TorusGeometry(config.radius, 0.008, 6, 180),
        );
        const material = own(
          new T.MeshBasicMaterial({
            color: config.z > 0 ? 0xf7f7f4 : 0x8d8d88,
            transparent: true,
            opacity: config.opacity,
            depthWrite: false,
          }),
        );
        const ring = new T.Mesh(geometry, material);
        ring.rotation.x = Math.PI / 2;
        ring.rotation.y = config.tilt;
        ring.rotation.z = config.z;
        rings.push(ring);
        world.add(ring);
      });

      if (!(await stage(24, "Placing nine providers"))) return;

      /* ---- Nine nodes for nine operations ------------------------ */
      const layout = nodeLayout(NODES, SHELL);
      const nodeGroup = new T.Group();
      const nodeMaterials: import("three").MeshBasicMaterial[] = [];
      const nodeSprites: import("three").Sprite[] = [];
      const linkGeometry = own(new T.BufferGeometry());
      const linkPoints: number[] = [];

      layout.forEach((spot) => {
        const geometry = own(new T.OctahedronGeometry(0.13, 0));
        const material = own(
          new T.MeshBasicMaterial({
            color: 0xf7f7f4,
            transparent: true,
            opacity: 0.85,
          }),
        );
        nodeMaterials.push(material);
        const node = new T.Mesh(geometry, material);
        node.position.set(spot.x, spot.y, spot.z);
        node.scale.setScalar(spot.scale);
        nodeGroup.add(node);

        const halo = new T.Sprite(
          own(
            new T.SpriteMaterial({
              map: glow,
              color: 0xf7f7f4,
              transparent: true,
              opacity: 0.5,
              depthWrite: false,
              blending: T.AdditiveBlending,
            }),
          ),
        );
        halo.position.copy(node.position);
        halo.scale.setScalar(1.5 * spot.scale);
        nodeSprites.push(halo);
        nodeGroup.add(halo);

        // A chord back to the core: every provider answers to the same file.
        linkPoints.push(0, 0, 0, spot.x, spot.y, spot.z);
      });

      linkGeometry.setAttribute(
        "position",
        new T.BufferAttribute(new Float32Array(linkPoints), 3),
      );
      const linkMaterial = own(
        new T.LineBasicMaterial({
          color: 0x8d8d88,
          transparent: true,
          opacity: 0.22,
          depthWrite: false,
        }),
      );
      nodeGroup.add(new T.LineSegments(linkGeometry, linkMaterial));

      const coreGeometry = own(new T.IcosahedronGeometry(0.36, 1));
      const coreMaterial = own(
        new T.MeshBasicMaterial({ color: 0xffffff, transparent: true }),
      );
      const core = new T.Mesh(coreGeometry, coreMaterial);
      const coreHalo = new T.Sprite(
        own(
          new T.SpriteMaterial({
            map: glow,
            color: 0xf7f7f4,
            transparent: true,
            opacity: 0.55,
            depthWrite: false,
            blending: T.AdditiveBlending,
          }),
        ),
      );
      coreHalo.scale.setScalar(3.4);
      nodeGroup.add(core, coreHalo);
      world.add(nodeGroup);

      /* ---- The sweep: an instrument looking for something -------- */
      const sweepGeometry = own(
        new T.TorusGeometry(SHELL * 1.06, 0.011, 6, 190),
      );
      const sweepMaterial = own(
        new T.MeshBasicMaterial({
          color: 0xffffff,
          transparent: true,
          opacity: 0.5,
          depthWrite: false,
          blending: T.AdditiveBlending,
        }),
      );
      const sweep = new T.Mesh(sweepGeometry, sweepMaterial);
      sweep.rotation.x = Math.PI / 2;
      world.add(sweep);

      if (!(await stage(58, "Wiring the background"))) return;

      /* ---- Dust -------------------------------------------------- */
      const dustCount = compact ? 260 : 620;
      const dustGeometry = own(new T.BufferGeometry());
      const dustPositions = new Float32Array(dustCount * 3);
      for (let i = 0; i < dustCount; i++) {
        const u = Math.random() * 2 - 1;
        const theta = Math.random() * Math.PI * 2;
        const r = Math.sqrt(1 - u * u);
        const radius = 8 + Math.random() * 9;
        dustPositions[i * 3] = Math.cos(theta) * r * radius;
        dustPositions[i * 3 + 1] = u * radius * 0.7;
        dustPositions[i * 3 + 2] = Math.sin(theta) * r * radius;
      }
      dustGeometry.setAttribute(
        "position",
        new T.BufferAttribute(dustPositions, 3),
      );
      const dustMaterial = own(
        new T.PointsMaterial({
          size: 0.055,
          map: glow,
          color: 0xbdbdb8,
          transparent: true,
          opacity: 0.24,
          depthWrite: false,
          blending: T.AdditiveBlending,
          sizeAttenuation: true,
        }),
      );
      const dust = new T.Points(dustGeometry, dustMaterial);
      scene.add(dust);

      const layoutX = width > 1080 ? 2.5 : width > 780 ? 1.2 : 0;
      world.position.x = layoutX;
      scene.add(world);

      const resize = () => {
        width = node.clientWidth || 1;
        height = node.clientHeight || 1;
        camera.aspect = width / height;
        camera.fov = width < 780 ? 52 : 42;
        camera.updateProjectionMatrix();
        renderer.setSize(width, height);
        renderer.setPixelRatio(
          Math.min(window.devicePixelRatio || 1, width < 780 ? 1.3 : 1.75),
        );
      };
      window.addEventListener("resize", resize);
      listeners.push(() => window.removeEventListener("resize", resize));

      const move = (event: PointerEvent) => {
        pointerX = (event.clientX / window.innerWidth - 0.5) * 2;
        pointerY = (event.clientY / window.innerHeight - 0.5) * 2;
      };
      window.addEventListener("pointermove", move, { passive: true });
      listeners.push(() => window.removeEventListener("pointermove", move));

      if (!(await stage(84, "Focusing"))) return;

      /* ---- Frame ------------------------------------------------- */
      let revealed = false;

      const render = (time: number, animate: boolean) => {
        const look = cameraAt(state.current.progress.current);
        const targetX = pointerX * 0.85;
        const targetY = look.tilt * 6.4 - pointerY * 0.6;

        camera.position.x += (targetX - camera.position.x) * 0.055;
        camera.position.y += (targetY - camera.position.y) * 0.055;
        camera.position.z += (look.distance - camera.position.z) * 0.055;
        camera.lookAt(layoutX * 0.32, 0, 0);

        world.rotation.y = look.spin * 0.42 + time * 0.028;
        world.rotation.x = Math.sin(time * 0.14) * 0.06;

        if (animate) {
          const sweepY = Math.sin(time * 0.42) * 4.3;
          sweep.position.y = sweepY;
          sweepMaterial.opacity = 0.18 + 0.3 * (1 - Math.abs(sweepY) / 4.6);
          sweep.scale.setScalar(1 - Math.abs(sweepY) / 22);
        }

        // One node at a time leans forward, the way a cursor moves down a menu.
        const cursor = (time * 0.34) % NODES;
        nodeMaterials.forEach((material, index) => {
          const distance = Math.min(
            Math.abs(index - cursor),
            NODES - Math.abs(index - cursor),
          );
          const near = Math.max(0, 1 - distance / 1.7);
          material.opacity = 0.6 + near * 0.4;
          const halo = nodeSprites[index];
          if (halo) {
            halo.scale.setScalar((1.5 + near * 1.5) * layout[index].scale);
            (halo.material as import("three").SpriteMaterial).opacity =
              0.32 + near * 0.42;
          }
        });

        core.rotation.y = time * 0.5;
        core.rotation.z = time * 0.22;
        coreMaterial.opacity = 0.82 + Math.sin(time * 1.6) * 0.18;

        renderer.render(scene, camera);

        if (!revealed) {
          revealed = true;
          renderer.domElement.style.opacity = "1";
          state.current.onLoad({
            status: "ready",
            progress: 100,
            stage: "Online",
          });
        }
      };

      const loop = (now: number) => {
        if (disposed || failed) return;
        raf = 0;
        if (state.current.active) {
          const delta = last ? Math.min(0.05, (now - last) / 1000) : 0;
          last = now;
          if (!state.current.paused) clock += delta;
          render(clock, !state.current.paused);
        }
        if (!state.current.paused) raf = requestAnimationFrame(loop);
      };
      const restart = () => {
        if (disposed || failed) return;
        last = 0;
        cancelAnimationFrame(raf);
        if (state.current.paused) {
          render(clock, false);
          return;
        }
        raf = requestAnimationFrame(loop);
      };
      // The page pokes this whenever progress, pause or visibility changes.
      draw.current = restart;
      restart();
    }

    setup().catch(() => fallback());

    return () => {
      disposed = true;
      cleanup();
    };
  }, []);

  return <div ref={host} className="deck-canvas" aria-hidden="true" />;
}
