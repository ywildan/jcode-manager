import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import "./globals.css";
import { Toaster } from "@/components/ui/sonner";

const display = localFont({
  src: "./fonts/SpaceGrotesk-Variable.ttf",
  variable: "--font-display",
  weight: "300 700",
  display: "swap",
});

const mono = localFont({
  src: "./fonts/GeistMono-Variable.woff2",
  variable: "--font-mono",
  weight: "100 900",
  display: "swap",
});

const origin =
  process.env.NEXT_PUBLIC_SITE_URL || "https://jcode-manager.vercel.app";
const title = "Jcode Manager — Every provider. One menu.";
const description =
  "An interactive manager for jcode CLI providers: add, list, edit, delete, quick-start, generate, launch and restore OpenAI-compatible profiles without hand-editing TOML. Linux, macOS and Windows, with Python 3.8+ or plain bash. No dependencies, MIT.";

export const metadata: Metadata = {
  metadataBase: new URL(origin),
  title,
  description,
  applicationName: "Jcode Manager",
  authors: [{ name: "LN", url: "https://lndev.me" }],
  category: "developer tools",
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    locale: "en_US",
    url: "/",
    siteName: "Jcode Manager",
    title,
    description,
  },
  twitter: {
    card: "summary_large_image",
    title,
    description,
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  themeColor: "#000000",
  colorScheme: "dark",
};

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`dark ${display.variable} ${mono.variable}`}>
      <body className={display.className}>
        <noscript>
          <style>{`.curtain{display:none!important}.shell{visibility:visible!important;opacity:1!important}html:has(.curtain),body:has(.curtain){overflow:auto!important}.skip{visibility:visible!important}`}</style>
        </noscript>
        <a className="skip" href="#main">
          Skip to the content
        </a>
        {children}
        <Toaster theme="dark" />
      </body>
    </html>
  );
}
