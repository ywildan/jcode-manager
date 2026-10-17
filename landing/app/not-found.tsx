import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function NotFound() {
  return (
    <main
      style={{
        display: "flex",
        minHeight: "100svh",
        flexDirection: "column",
        alignItems: "flex-start",
        justifyContent: "center",
        gap: "1.4rem",
        padding: "clamp(2rem, 8vw, 8rem)",
        background: "#000000",
        color: "#f7f7f4",
      }}
    >
      <p
        style={{
          fontFamily: "var(--font-mono)",
          color: "#a6a6a0",
          fontSize: 12,
          letterSpacing: "0.2em",
          textTransform: "uppercase",
        }}
      >
        Jcode Manager / signal 404
      </p>
      <h1
        style={{
          fontSize: "clamp(2.6rem, 8vw, 7rem)",
          lineHeight: 0.92,
          letterSpacing: "-.06em",
          margin: 0,
          fontWeight: 500,
        }}
      >
        No such plate.
      </h1>
      <p style={{ color: "#a6a6a0", maxWidth: "52ch", margin: 0 }}>
        This route is not part of the deck. The nine operations live on the home
        page, and nothing here writes to your config.
      </p>
      <Button nativeButton={false} render={<Link href="/" />}>
        Back to the deck
      </Button>
    </main>
  );
}
