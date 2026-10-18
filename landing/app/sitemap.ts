import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const origin =
    process.env.NEXT_PUBLIC_SITE_URL || "https://jcode-manager.vercel.app";
  return [
    { url: new URL("/", origin).href, changeFrequency: "monthly", priority: 1 },
  ];
}
