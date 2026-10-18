"use client";

import type { ReactNode } from "react";
import { ArrowUpRight, CircleCheck, TriangleAlert } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Code, CopyButton } from "@/components/code";
import { Replay } from "@/components/replay";
import { Studio } from "@/components/studio";
import {
  binaryLookup,
  brokenConfig,
  cliCommands,
  correctConfig,
  daemonWarning,
  engines,
  envVars,
  faq,
  gotchas,
  installFlags,
  installSteps,
  keyStoreModes,
  launchSteps,
  menu,
  pathTable,
  safety,
  testSuites,
  verification,
} from "@/lib/content";

export function PlateHead({
  index,
  eyebrow,
  title,
  lede,
}: {
  index: string;
  eyebrow: string;
  title: ReactNode;
  lede?: ReactNode;
}) {
  return (
    <div className="plate-head" data-reveal>
      <div className="plate-head-copy">
        <span className="eyebrow">
          <span className="tick" />
          {eyebrow}
        </span>
        <h2>{title}</h2>
        {lede ? <p className="lede">{lede}</p> : null}
      </div>
      <span className="plate-index">
        <b>{index}</b>
        plate
      </span>
    </div>
  );
}

function Plate({
  id,
  children,
  className,
}: {
  id: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={className ? `plate ${className}` : "plate"} id={id}>
      <div className="rail plate-inner">{children}</div>
    </section>
  );
}

/* ------------------------------------------------------------------ */

export function FilePlate() {
  return (
    <Plate id="problem">
      <PlateHead
        index="01"
        eyebrow="The file that decides everything"
        title={
          <>
            jcode reads one file.
            <br />
            Three details decide <em>if it works.</em>
          </>
        }
        lede="A provider profile is a [providers.<name>] section in ~/.jcode/config.toml. These three mistakes are silent, confusing, or fatal, and the manager exists so you never have to remember them."
      />

      <div className="ledger" data-reveal>
        <div className="slab" data-ok="false">
          <div className="slab-head">
            <span className="state">hand-written · wrong</span>
            <span>jcode ignores or refuses it</span>
          </div>
          <div className="slab-body">
            <Code text={brokenConfig} lang="toml" />
          </div>
        </div>
        <div className="slab" data-ok="true">
          <div className="slab-head">
            <span className="state">what the manager writes</span>
            <span>validated before it lands</span>
          </div>
          <div className="slab-body">
            <Code text={correctConfig} lang="toml" />
          </div>
        </div>
      </div>

      <div className="gotcha-grid">
        {gotchas.map((item) => (
          <article className="gotcha" key={item.index}>
            <span className="frac">{item.index}</span>
            <h3>{item.title}</h3>
            <p>{item.body}</p>
          </article>
        ))}
      </div>

      <div className="table-wrap" data-reveal>
        <table>
          <caption>Where the API key can live</caption>
          <thead>
            <tr>
              <th scope="col">Mode</th>
              <th scope="col">The config contains</th>
              <th scope="col">The key itself lives in</th>
              <th scope="col">Good for</th>
            </tr>
          </thead>
          <tbody>
            {keyStoreModes.map((mode) => (
              <tr key={mode.id}>
                <th scope="row">
                  <code>{mode.name}</code>
                </th>
                <td>
                  <code>{mode.config}</code>
                </td>
                <td>{mode.location}</td>
                <td>{mode.good}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Plate>
  );
}

/* ------------------------------------------------------------------ */

export function MenuPlate() {
  return (
    <Plate id="menu">
      <PlateHead
        index="02"
        eyebrow="The menu"
        title={
          <>
            Nine operations.
            <br />
            <em>No TOML to memorise.</em>
          </>
        }
        lede="Every provider task has a number. Pick it, answer the prompts, press Enter to come back to where you were."
      />

      <Replay />

      <div className="menu-grid" style={{ marginTop: "clamp(30px, 4vw, 52px)" }}>
        {menu.map((item) => (
          <article className="menu-card" key={item.id} id={`menu-${item.id}`}>
            <div className="menu-card-top">
              <span className="num">{item.id}</span>
              <span className="kind">{item.tag}</span>
            </div>
            <h3>{item.name}</h3>
            <p>{item.summary}</p>
          </article>
        ))}
      </div>
    </Plate>
  );
}

/* ------------------------------------------------------------------ */

export function LaunchPlate() {
  return (
    <Plate id="launch">
      <PlateHead
        index="03"
        eyebrow="The daemon"
        title={
          <>
            Your flags are ignored
            <br />
            <em>while the daemon runs.</em>
          </>
        }
        lede="jcode keeps a persistent background server. --provider and --provider-profile only apply when that server starts fresh. Ask jcode with a running daemon and it tells you so, politely, and does nothing. Menu 7 handles the order."
      />

      <div className="flow">
        <ol className="flow-steps" data-reveal>
          {launchSteps.map((step) => (
            <li className="flow-step" key={step.index}>
              <span className="frac">{step.index}</span>
              <div>
                <code>{step.command}</code>
                <p>{step.detail}</p>
              </div>
            </li>
          ))}
        </ol>

        <div style={{ display: "grid", gap: 22 }}>
          <div className="daemon-state">
            <span data-live="false">daemon running — flags will be dropped</span>
            <span data-live="false">
              this is what the manager finds and fixes
            </span>
            <span data-live="true">
              daemon stopped — flags attach to the new server
            </span>
            <span data-live="true">and your profile is the one jcode uses</span>
          </div>
          <div className="warning">
            <span className="eyebrow">
              <TriangleAlert size={13} aria-hidden="true" /> Before you press
              launch
            </span>
            <p>{daemonWarning}</p>
          </div>
          <div className="slab">
            <div className="slab-head">
              <span className="state" data-ok="true">
                menu 7 · what actually runs
              </span>
              <CopyButton
                value={["jcode server stop --force", "sleep 0.5", "jcode --provider openai-compatible --provider-profile mygw --model gpt-4o"].join("\n")}
                label="Copy"
              />
            </div>
            <div className="slab-body">
              <Code
                text={[
                  "jcode server stop --force   # errors ignored when idle",
                  "sleep 0.5                   # let the socket go",
                  "jcode --provider openai-compatible --provider-profile mygw \\",
                  "      --model gpt-4o        # fresh start, flags apply",
                ].join("\n")}
              />
            </div>
          </div>
        </div>
      </div>
    </Plate>
  );
}

/* ------------------------------------------------------------------ */

export function StudioPlate() {
  return (
    <Plate id="studio">
      <PlateHead
        index="04"
        eyebrow="Provider studio"
        title={
          <>
            Build a profile here.
            <br />
            <em>See what lands in the file.</em>
          </>
        }
        lede="Pick a template, rename the profile, choose where the key lives. The preview updates as you type, and nothing leaves your browser."
      />
      <Studio />
    </Plate>
  );
}

/* ------------------------------------------------------------------ */

export function SafetyPlate() {
  return (
    <Plate id="safety">
      <PlateHead
        index="05"
        eyebrow="Safety"
        title={
          <>
            It writes to your config.
            <br />
            <em>It behaves like it knows that.</em>
          </>
        }
        lede="Eight rules the manager keeps on every single write. None of them are optional, and none of them depend on you remembering anything."
      />
      <div className="safety-grid">
        {safety.map((item) => (
          <article className="safety-card" key={item.id}>
            <span className="frac">{item.id}</span>
            <h3>{item.title}</h3>
            <p>{item.body}</p>
          </article>
        ))}
      </div>
    </Plate>
  );
}

/* ------------------------------------------------------------------ */

export function InstallPlate() {
  return (
    <Plate id="install">
      <PlateHead
        index="06"
        eyebrow="Install"
        title={
          <>
            One command, then
            <br />
            <em>a menu you already understand.</em>
          </>
        }
        lede="No package manager, no virtualenv, no service. install.sh checks what you have, marks the scripts executable and prints the paths it will use."
      />

      <div className="install-grid">
        {installSteps.map((step) => (
          <article className="install-card" key={step.index}>
            <div className="install-card-top">
              <span className="num">{step.index}</span>
              <CopyButton value={step.copy} label="Copy" />
            </div>
            <h3>{step.title}</h3>
            <div className="slab-body">
              <Code text={step.copy} />
            </div>
            <p>{step.body}</p>
          </article>
        ))}
      </div>

      <ul className="flag-list" data-reveal>
        {installFlags.map((flag) => (
          <li key={flag.flag}>
            <code>{flag.flag}</code>
            <span>{flag.body}</span>
          </li>
        ))}
      </ul>
    </Plate>
  );
}

/* ------------------------------------------------------------------ */

export function CommandsPlate() {
  return (
    <Plate id="commands">
      <PlateHead
        index="07"
        eyebrow="Non-interactive"
        title={
          <>
            Every feature,
            <br />
            <em>without the menu.</em>
          </>
        }
        lede="The same operations are available as flags, so they fit in scripts and CI. Nothing here needs a terminal prompt."
      />

      <div className="cli-groups">
        {cliCommands.map((group) => (
          <div className="cli-group" key={group.group}>
            <div className="cli-group-head">
              <span className="frac">{group.group}</span>
              <span>{group.items.length} commands</span>
            </div>
            <div className="cli-list">
              {group.items.map((item) => (
                <div className="cli-row" key={item.command}>
                  <div>
                    <Code text={item.command} />
                    <p>{item.body}</p>
                  </div>
                  <CopyButton value={item.command} label="Copy" />
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div className="env-list" data-reveal>
        {envVars.map((item) => (
          <div className="env-row" key={item.name}>
            <code>{item.name}</code>
            <span>{item.purpose}</span>
          </div>
        ))}
      </div>
    </Plate>
  );
}

/* ------------------------------------------------------------------ */

function state(mark: string) {
  if (mark === "tested live") return "live";
  if (mark.startsWith("not")) return "never";
  return "idle";
}

export function EnginesPlate() {
  return (
    <Plate id="engines">
      <PlateHead
        index="08"
        eyebrow="Engines and platforms"
        title={
          <>
            Python if you have it.
            <br />
            <em>bash if you do not.</em>
          </>
        }
        lede="The launcher picks an engine on its own, and you can force either one with JCODE_MANAGER_ENGINE. The config format and the safety rails are identical."
      />

      <div className="engine-grid">
        {engines.map((engine) => (
          <article
            className="engine-card"
            data-tone={engine.tone}
            key={engine.name}
          >
            <span className="eyebrow">
              <span className="tick" />
              {engine.when}
            </span>
            <h3>{engine.name}</h3>
            <p>{engine.body}</p>
            <ul className="engine-list">
              {engine.list.map((line) => (
                <li key={line}>{line}</li>
              ))}
            </ul>
          </article>
        ))}
      </div>

      <div className="table-wrap" data-reveal>
        <table>
          <caption>Paths per OS</caption>
          <thead>
            <tr>
              <th scope="col">OS</th>
              <th scope="col">Config</th>
              <th scope="col">Provider env files</th>
            </tr>
          </thead>
          <tbody>
            {pathTable.map((row) => (
              <tr key={row.os}>
                <th scope="row">{row.os}</th>
                <td>
                  <code>{row.config}</code>
                </td>
                <td>
                  <code>{row.env}</code>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="table-wrap" data-reveal>
        <table>
          <caption>The jcode binary is looked up in this order</caption>
          <thead>
            <tr>
              <th scope="col">OS</th>
              <th scope="col">Search path</th>
            </tr>
          </thead>
          <tbody>
            {binaryLookup.map((row) => (
              <tr key={row.os}>
                <th scope="row">{row.os}</th>
                <td>
                  <code>{row.path}</code>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="table-wrap" data-reveal>
        <table>
          <caption>
            Verification status — including what has not been tested yet
          </caption>
          <thead>
            <tr>
              <th scope="col">Area</th>
              <th scope="col">Linux</th>
              <th scope="col">macOS</th>
              <th scope="col">Windows</th>
            </tr>
          </thead>
          <tbody>
            {verification.map((row) => (
              <tr key={row.area}>
                <th scope="row">{row.area}</th>
                <td>
                  <span className="pill" data-state={state(row.linux)}>
                    {row.linux}
                  </span>
                </td>
                <td>
                  <span className="pill" data-state={state(row.mac)}>
                    {row.mac}
                  </span>
                </td>
                <td>
                  <span className="pill" data-state={state(row.win)}>
                    {row.win}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="checks-note">
        “Simulated” means the Windows and macOS branches were exercised by
        patching os.name, sys.platform and the platform-specific environment
        variables — not that they ran on those systems. The PowerShell launcher
        could not be tested at all: no PowerShell on the test machine.
      </p>
    </Plate>
  );
}

/* ------------------------------------------------------------------ */

export function ChecksPlate() {
  return (
    <Plate id="checks">
      <PlateHead
        index="09"
        eyebrow="Testing"
        title={
          <>
            157 checks.
            <br />
            <em>Your config is never one of them.</em>
          </>
        }
        lede="Four suites, from cheapest to strictest. Every one of them runs against a throwaway config in a temp directory, so the tests can never touch your real providers."
      />

      <div className="check-grid">
        {testSuites.map((suite) => (
          <article className="check" key={suite.name}>
            <span className="count">{suite.count}</span>
            <h3>{suite.name}</h3>
            <code>{suite.engine}</code>
            <p>{suite.body}</p>
          </article>
        ))}
      </div>

      <p className="checks-note">
        The acceptance suite runs the real jcode binary inside a bubblewrap
        sandbox with its own HOME and its own daemon socket. It proves that both
        engines write configs `jcode provider current` accepts, that
        default_model is the model actually used, that the key really travels as
        an Authorization: Bearer header, that envfile mode works end to end, and
        that server stop --force genuinely clears the socket. Last recorded run
        on Linux: 16 ok / 0 fail, 64 ok / 0 fail, 57 ok / 0 fail, 20 ok / 0 fail.
      </p>
    </Plate>
  );
}

/* ------------------------------------------------------------------ */

export function FaqPlate() {
  return (
    <Plate id="faq">
      <PlateHead
        index="10"
        eyebrow="Questions"
        title={
          <>
            Ten answers,
            <br />
            <em>including the errors you will actually see.</em>
          </>
        }
      />

      <div className="faq-layout">
        <aside className="faq-aside" data-reveal>
          <span className="eyebrow">
            <span className="tick" />
            Read the source
          </span>
          <h3>Everything is plain files</h3>
          <p>
            No binary, no build step, no dependencies. The Python engine, the bash
            engine, the installer and the tests are all readable text in one
            folder.
          </p>
          <ul className="engine-list">
            <li>jcode-manager.py — the primary engine</li>
            <li>jcode-manager.sh — launcher + bash engine</li>
            <li>jcode-manager.ps1 — Windows launcher</li>
            <li>install.sh, create-shortcut.sh</li>
            <li>tests/ — 157 checks</li>
          </ul>
          <p>
            The interactive prompts inside the scripts are Indonesian and English
            mixed, which is the original author&rsquo;s style. There is no runtime
            language switch yet.
          </p>
        </aside>

        <div className="faq-list" data-reveal>
          <Accordion>
            {faq.map((item, index) => (
              <AccordionItem
                className="ui-accordion-item faq-item"
                key={item.q}
                value={`faq-${index}`}
              >
                <AccordionTrigger className="ui-accordion-trigger">
                  {item.q}
                </AccordionTrigger>
                <AccordionContent className="ui-accordion-content">
                  {item.a}
                </AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </div>
      </div>
    </Plate>
  );
}

/* ------------------------------------------------------------------ */

export function OutroPlate() {
  return (
    <section className="plate outro" id="outro">
      <div className="rail outro-inner" data-reveal>
        <span className="eyebrow">
          <span className="tick" />
          Start where you are
        </span>
        <h2>
          Point jcode at something new <em>tonight.</em>
        </h2>
        <p className="lede">
          Clone the folder, run ./install.sh, press 5 for a template, and paste a
          key. The next model you try costs you about ninety seconds and one
          hand-written config file fewer.
        </p>
        <div className="outro-actions">
          <Button
            className="cta"
            nativeButton={false}
            render={<a href="#install" />}
          >
            <span>Go to the install steps</span>
            <span className="cta-orbit">
              <ArrowUpRight size={18} aria-hidden="true" />
            </span>
          </Button>
          <Button
            variant="outline"
            className="cta-ghost"
            nativeButton={false}
            render={<a href="#commands" />}
          >
            Command reference
            <CircleCheck size={16} aria-hidden="true" />
          </Button>
        </div>
        <p className="mono-note">
          No account, no telemetry, no email. Nothing on this page is submitted
          anywhere.
        </p>
      </div>
    </section>
  );
}
