const DENY_MAP = {
  cat: { suggestion: "rtk read" },
  ls: { suggestion: "rtk ls or rtk tree" },
  grep: { suggestion: "rtk grep" },
  find: { suggestion: "rtk find" },
  rg: { suggestion: "rtk grep" },
  eza: { suggestion: "rtk ls or rtk tree" },
  fd: { suggestion: "rtk find" },
  bat: { suggestion: "rtk read" },
  dust: { suggestion: "du -s (parseable; dust is for humans)" },
  du: { suggestion: "du -s or du -sh only" },
  git: { suggestion: "rtk git …" },
  gh: { suggestion: "rtk gh …" },
  rm: { suggestion: "ask the captain before deleting files" },
  sudo: { suggestion: "ask the captain before privilege escalation" },
  security: { suggestion: "ask the captain before Keychain access" },
  export: { suggestion: "use secret-cache exec instead of exporting secrets" },
  gcat: { suggestion: "rtk read" },
  gls: { suggestion: "rtk ls or rtk tree" },
  ggrep: { suggestion: "rtk grep" },
  gfind: { suggestion: "rtk find" },
  gdu: { suggestion: "du -s or du -sh only" },
  gsed: { suggestion: "fastedit edit or jq/yq for structured data" },
  gawk: { suggestion: "jq/yq for structured data or rtk grep for text" },
};

export default async () => ({
  "permission.ask": async (input, output) => {
    if (input.type === "bash") {
      const pattern = input.pattern || "";
      const cmd = pattern.trim().split(/\s+/)[0]?.toLowerCase();
      const rule = DENY_MAP[cmd];
      if (!rule) return;
      if (cmd === "du" && /\bdu\s+-s/.test(pattern)) return;
      output.status = "deny";
      input.metadata = {
        ...input.metadata,
        toolGuardReason: `Use ${rule.suggestion} instead of ${cmd}`,
      };
      return;
    }

    const nativeRedirect = {
      read: "rtk read via bash",
      grep: "rtk grep via bash",
      glob: "rtk find via bash",
      list: "rtk ls via bash",
    };
    const suggestion = nativeRedirect[input.type];
    if (!suggestion) return;
    output.status = "deny";
    input.metadata = {
      ...input.metadata,
      toolGuardReason: `Native ${input.type} is disabled. Use ${suggestion}`,
    };
  },
});
