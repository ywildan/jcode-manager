"use client";

import { useMemo, useState } from "react";
import { AlertTriangle } from "lucide-react";
import { Input } from "@/components/ui/input";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Code, CopyButton } from "@/components/code";
import { providerTemplates } from "@/lib/content";

const NAME_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_-]*$/;

type Mode = "inline" | "envfile";

export function Studio() {
  const [templateId, setTemplateId] = useState(providerTemplates[0].id);
  const [name, setName] = useState(providerTemplates[0].provider);
  const [baseUrl, setBaseUrl] = useState(providerTemplates[0].baseUrl);
  const [model, setModel] = useState(providerTemplates[0].model);
  const [mode, setMode] = useState<Mode>("inline");

  const template =
    providerTemplates.find((item) => item.id === templateId) ??
    providerTemplates[0];

  const pick = (id: string) => {
    const next = providerTemplates.find((item) => item.id === id);
    if (!next) return;
    setTemplateId(id);
    setName(next.provider);
    setBaseUrl(next.baseUrl);
    setModel(next.model);
  };

  const profile = name.trim() || "mygw";
  const validName = NAME_PATTERN.test(profile);
  const validUrl = /^https?:\/\/\S+$/.test(baseUrl.trim());
  const localNoAuth = /^https?:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])/.test(
    baseUrl.trim(),
  );

  const envKey = `JCODE_${profile.replace(/[^A-Za-z0-9]/g, "_").toUpperCase()}_API_KEY`;

  const config = useMemo(() => {
    const lines = [
      `[providers.${profile}]`,
      `base_url = "${baseUrl.trim()}"`,
    ];
    if (mode === "inline") {
      lines.push(localNoAuth ? 'api_key = ""' : 'api_key = "sk-…"');
    } else {
      lines.push(`api_key_env = "${envKey}"`);
      lines.push(
        `env_file = "<XDG_CONFIG_HOME>/jcode/provider-${profile}.env"`,
      );
    }
    lines.push(`default_model = "${model.trim()}"`);
    return lines.join("\n");
  }, [baseUrl, envKey, localNoAuth, mode, model, profile]);

  const command = useMemo(() => {
    const add = localNoAuth
      ? `python3 jcode-manager.py --add ${profile} \\\n    --base-url ${baseUrl.trim()} --api-key "" --model ${model.trim()}`
      : `python3 jcode-manager.py --add ${profile} \\\n    --base-url ${baseUrl.trim()} --api-key-stdin --model ${model.trim()}`;
    const launch = [
      "# stop the daemon first: the profile flags only apply on a fresh start",
      "jcode server stop --force",
      `jcode --provider openai-compatible --provider-profile ${profile} --model ${model.trim()}`,
    ].join("\n");
    return `${add}\n\n${launch}`;
  }, [baseUrl, localNoAuth, model, profile]);

  return (
    <div className="studio">
      <div className="studio-form">
        <div className="field">
          <span className="field-label" id="template-label">
            01 / Start from a template
          </span>
          <RadioGroup
            value={templateId}
            onValueChange={pick}
            aria-labelledby="template-label"
          >
            {providerTemplates.map((item) => (
              <RadioGroupItem key={item.id} value={item.id} className="ui-radio">
                {item.name}
              </RadioGroupItem>
            ))}
          </RadioGroup>
          <p className="mono-note">{template.note}</p>
        </div>

        <div className="field">
          <label htmlFor="studio-name">02 / Provider name</label>
          <Input
            id="studio-name"
            value={name}
            spellCheck={false}
            autoComplete="off"
            aria-invalid={!validName}
            aria-describedby="studio-name-hint"
            onChange={(event) => setName(event.target.value)}
          />
          <p className="mono-note" id="studio-name-hint">
            {validName
              ? "Letters, digits, dashes and underscores. This becomes [providers.<name>]."
              : "That name will not work as a TOML table key. Use letters, digits, dashes and underscores."}
          </p>
        </div>

        <div className="field">
          <label htmlFor="studio-url">03 / Base URL</label>
          <Input
            id="studio-url"
            value={baseUrl}
            spellCheck={false}
            autoComplete="off"
            aria-invalid={!validUrl}
            onChange={(event) => setBaseUrl(event.target.value)}
          />
        </div>

        <div className="field">
          <label htmlFor="studio-model">04 / Default model</label>
          <Input
            id="studio-model"
            value={model}
            spellCheck={false}
            autoComplete="off"
            onChange={(event) => setModel(event.target.value)}
          />
          <p className="mono-note">
            Written as default_model. A plain <code>model</code> key is ignored by
            jcode without an error.
          </p>
        </div>

        <div className="field">
          <span className="field-label" id="mode-label">
            05 / Where the key lives
          </span>
          <RadioGroup
            value={mode}
            onValueChange={(value) => setMode(value as Mode)}
            aria-labelledby="mode-label"
            className="ui-radio-group-2"
          >
            <RadioGroupItem value="inline" className="ui-radio">
              inline
            </RadioGroupItem>
            <RadioGroupItem value="envfile" className="ui-radio">
              envfile
            </RadioGroupItem>
          </RadioGroup>
        </div>
      </div>

      <div className="studio-out">
        <div className="slab" data-tilt>
          <div className="slab-head">
            <span className="state" data-ok="true">
              preview · nothing is written
            </span>
            <CopyButton value={`${config}\n`} label="Copy config" />
          </div>
          <div className="slab-body">
            <Code text={config} lang="toml" />
          </div>
        </div>

        <div className="slab">
          <div className="slab-head">
            <span className="state" data-ok="true">
              menu 6 · generate command
            </span>
            <CopyButton value={command} label="Copy command" />
          </div>
          <div className="slab-body">
            <Code text={command} />
          </div>
        </div>

        <div className="warning">
          <span className="eyebrow">
            <AlertTriangle size={13} aria-hidden="true" /> A preview, not a form
          </span>
          <p>
            This studio is a demonstration: it writes nothing, stores nothing and
            sends nothing. Your API key is never asked for here. Run the real
            command in your own terminal, and verify the endpoint with your
            provider before you rely on it.
          </p>
        </div>
      </div>
    </div>
  );
}
