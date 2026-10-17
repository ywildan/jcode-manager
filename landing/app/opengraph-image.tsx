import { ImageResponse } from "next/og";

export const alt =
  "Jcode Manager — every provider, one menu. A black control deck for jcode CLI providers.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

const paper = "#f7f7f4";
const ash = "#a6a6a0";
const dim = "#71716b";

export default function Image() {
  return new ImageResponse(
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        padding: "52px 64px",
        background: "#000000",
        color: paper,
        fontFamily: "sans-serif",
        overflow: "hidden",
      }}
    >
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          fontSize: 15,
          letterSpacing: "3px",
          color: ash,
        }}
      >
        <span>AN INTERACTIVE MANAGER FOR JCODE PROVIDERS</span>
        <span style={{ color: paper }}>JCODE V0.98.1</span>
      </div>

      {/* Concentric rounded squares: the deck's mark, enlarged. */}
      <div
        style={{
          position: "absolute",
          display: "flex",
          right: 54,
          top: 132,
          width: 300,
          height: 300,
          borderRadius: 72,
          border: "1px solid #ffffff2e",
          transform: "rotate(12deg)",
        }}
      />
      <div
        style={{
          position: "absolute",
          display: "flex",
          right: 104,
          top: 182,
          width: 200,
          height: 200,
          borderRadius: 48,
          border: "1px solid #ffffff1f",
          transform: "rotate(-8deg)",
        }}
      />
      <div
        style={{
          position: "absolute",
          display: "flex",
          right: 164,
          top: 242,
          width: 80,
          height: 80,
          borderRadius: 24,
          background: paper,
        }}
      />

      <div style={{ display: "flex", flexDirection: "column", marginTop: 74 }}>
        <span
          style={{
            fontSize: 132,
            fontWeight: 700,
            letterSpacing: "-9px",
            lineHeight: 1,
          }}
        >
          JCODE
        </span>
        <span
          style={{
            fontSize: 132,
            fontWeight: 700,
            letterSpacing: "-9px",
            lineHeight: 1,
            color: "#ffffff",
            opacity: 0.42,
          }}
        >
          MANAGER
        </span>
        <span style={{ fontSize: 34, marginTop: 26, color: paper }}>
          Every provider. One menu.
        </span>
      </div>

      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          color: dim,
          fontSize: 16,
          letterSpacing: "1px",
        }}
      >
        <span>LINUX · MACOS · WINDOWS · PYTHON 3.8+ OR BASH</span>
        <span>NO DEPENDENCIES · MIT</span>
      </div>
    </div>,
    size,
  );
}
