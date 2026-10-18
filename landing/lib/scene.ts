/** Shared contract between the loading curtain, the page and the WebGL world. */

export type LoadState = {
  status: "loading" | "ready" | "fallback";
  progress: number;
  stage: string;
};

export const initialLoad: LoadState = {
  status: "loading",
  progress: 0,
  stage: "Reading the provider registry",
};

export const clamp = (value: number, min = 0, max = 1) =>
  Math.max(min, Math.min(max, value));

export const smooth = (value: number) => {
  const t = clamp(value);
  return t * t * (3 - 2 * t);
};

/**
 * Nine nodes for nine menu operations, spread with a golden spiral so the
 * constellation is even and identical on every load.
 */
export function nodeLayout(count = 9, radius = 5.1) {
  const golden = Math.PI * (3 - Math.sqrt(5));
  return Array.from({ length: count }, (_, index) => {
    const y = 1 - (index / Math.max(1, count - 1)) * 2;
    const r = Math.sqrt(Math.max(0, 1 - y * y));
    const theta = golden * index;
    return {
      x: Math.cos(theta) * r * radius,
      y: y * radius * 0.78,
      z: Math.sin(theta) * r * radius,
      scale: 1 - (index % 4) * 0.16,
    };
  });
}

/** Scroll marks, in viewport heights, where the camera changes its mind. */
export const cameraMarks = [
  { at: 0, distance: 13.4, tilt: 0.12, spin: 0.5 },
  { at: 1.4, distance: 11.2, tilt: 0.42, spin: 1.5 },
  { at: 3.2, distance: 12.6, tilt: -0.28, spin: 2.6 },
  { at: 5.4, distance: 10.4, tilt: 0.2, spin: 3.9 },
  { at: 8, distance: 14.2, tilt: 0.06, spin: 5.1 },
];

export function cameraAt(progress: number) {
  const p = Math.max(0, progress);
  let index = 0;
  while (index < cameraMarks.length - 2 && p > cameraMarks[index + 1].at) {
    index += 1;
  }
  const from = cameraMarks[index];
  const to = cameraMarks[index + 1] ?? from;
  const span = Math.max(0.0001, to.at - from.at);
  const local = smooth((p - from.at) / span);
  return {
    distance: from.distance + (to.distance - from.distance) * local,
    tilt: from.tilt + (to.tilt - from.tilt) * local,
    spin: from.spin + (to.spin - from.spin) * local,
  };
}
