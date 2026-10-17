"use client";

import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { Check, Copy } from "lucide-react";
import { cn } from "@/lib/utils";

type Token = { text: string; kind: string };

const CLASS: Record<string, string> = {
  plain: "",
  comment: "c-comment",
  key: "c-key",
  string: "c-string",
  flag: "c-flag",
  dim: "c-dim",
  warn: "c-warn",
  cmd: "c-cmd",
};

/** Split a comment off the end of a line without tripping on quoted hashes. */
function splitComment(line: string) {
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') quoted = !quoted;
    else if (char === "#" && !quoted) {
      return [line.slice(0, i), line.slice(i)] as const;
    }
  }
  return [line, ""] as const;
}

function valueTokens(value: string): Token[] {
  const tokens: Token[] = [];
  const pattern = /("[^"]*")|(\s+)|([^\s"]+)/g;
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(value))) {
    if (match[1]) tokens.push({ text: match[1], kind: "string" });
    else if (match[2]) tokens.push({ text: match[2], kind: "plain" });
    else if (match[3].startsWith("#"))
      tokens.push({ text: match[3], kind: "comment" });
    else tokens.push({ text: match[3], kind: "plain" });
  }
  return tokens;
}

function tomlLine(line: string): Token[] {
  const [code, comment] = splitComment(line);
  const tokens: Token[] = [];
  if (code.trim().startsWith("[")) {
    tokens.push({ text: code, kind: "key" });
    if (comment) tokens.push({ text: comment, kind: "comment" });
    return tokens;
  }
  const assignment = /^(\s*)([\w."'-]+)(\s*=\s*)([\s\S]*)$/.exec(code);
  if (assignment) {
    tokens.push({ text: assignment[1], kind: "plain" });
    tokens.push({ text: assignment[2], kind: "key" });
    tokens.push({ text: assignment[3], kind: "dim" });
    tokens.push(...valueTokens(assignment[4]));
  } else if (code) {
    tokens.push({ text: code, kind: "plain" });
  }
  if (comment) tokens.push({ text: comment, kind: "comment" });
  return tokens;
}

function shellLine(line: string): Token[] {
  const [code, comment] = splitComment(line);
  const trimmed = code.trimStart();
  const indent = code.slice(0, code.length - trimmed.length);
  if (trimmed.startsWith("#")) return [{ text: line, kind: "comment" }];

  const tokens: Token[] = [{ text: indent, kind: "plain" }];
  if (trimmed) {
    const pattern = /(--?[a-zA-Z][\w-]*)|('[^']*')|("[^"]*")|(\s+)|([^\s]+)/g;
    let match: RegExpExecArray | null;
    while ((match = pattern.exec(trimmed))) {
      if (match[1]) tokens.push({ text: match[1], kind: "flag" });
      else if (match[2] || match[3])
        tokens.push({ text: (match[2] ?? match[3]) as string, kind: "string" });
      else if (match[4]) tokens.push({ text: match[4], kind: "plain" });
      else tokens.push({ text: match[5], kind: "cmd" });
    }
  }
  if (comment) tokens.push({ text: comment, kind: "comment" });
  return tokens;
}

export function Code({
  text,
  lang = "shell",
  className,
}: {
  text: string;
  lang?: "shell" | "toml";
  className?: string;
}) {
  const lines = text.replace(/\s+$/, "").split("\n");
  return (
    <pre className={cn("code", className)}>
      {lines.map((line, index) => {
        const tokens = lang === "toml" ? tomlLine(line) : shellLine(line);
        return (
          <span className="ln" key={index}>
            {tokens.length ? (
              tokens.map((token, position) =>
                CLASS[token.kind] ? (
                  <span className={CLASS[token.kind]} key={position}>
                    {token.text}
                  </span>
                ) : (
                  <span key={position}>{token.text}</span>
                ),
              )
            ) : (
              <span>{"\u00A0"}</span>
            )}
          </span>
        );
      })}
    </pre>
  );
}

async function writeClipboard(value: string) {
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(value);
      return;
    } catch {
      // Insecure context, or the document is not focused: fall through.
    }
  }
  const field = document.createElement("textarea");
  field.value = value;
  field.setAttribute("readonly", "");
  field.style.position = "fixed";
  field.style.top = "0";
  field.style.opacity = "0";
  document.body.appendChild(field);
  field.select();
  const copied = document.execCommand("copy");
  field.remove();
  if (!copied) throw new Error("copy failed");
}

export function CopyButton({
  value,
  label = "Copy",
  className,
  toastLabel = "Copied to the clipboard",
}: {
  value: string;
  label?: string;
  className?: string;
  toastLabel?: string;
}) {
  const [copied, setCopied] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(
    () => () => {
      if (timer.current) clearTimeout(timer.current);
    },
    [],
  );

  const run = async () => {
    try {
      await writeClipboard(value);
      setCopied(true);
      toast(toastLabel, {
        id: "clipboard",
        description: "Paste it wherever you need it.",
        icon: <Check size={16} />,
      });
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(() => setCopied(false), 2200);
    } catch {
      toast("Copy is blocked in this browser", {
        id: "clipboard",
        description: "Select the text and copy it by hand.",
        icon: <Copy size={16} />,
      });
    }
  };

  return (
    <button
      type="button"
      className={cn("copy-button", className)}
      data-copied={copied}
      onClick={run}
    >
      {copied ? <Check size={13} aria-hidden="true" /> : <Copy size={13} aria-hidden="true" />}
      {copied ? "Copied" : label}
    </button>
  );
}
