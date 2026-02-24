import json from "@eslint/json";

export default [
  {
    files: ["**/*.json"],
    ignores: ["node_modules/**", "package-lock.json"],
    language: "json/json",
    ...json.configs.recommended,
  },
  {
    files: ["**/*.jsonc", ".devcontainer/devcontainer.json"],
    ignores: ["node_modules/**"],
    language: "json/jsonc",
    ...json.configs.recommended,
  },
];
