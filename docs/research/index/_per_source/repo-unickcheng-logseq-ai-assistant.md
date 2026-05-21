# Logseq AI Assistant Plugin

- **Source ID:** repo-unickcheng-logseq-ai-assistant
- **Kind:** repo
- **Path:** inspiration/repos/UNICKCHENG__logseq-ai-assistant
- **Density:** 2

## Elevator summary

A Logseq plugin that integrates OpenAI's GPT API into the knowledge management system, enabling in-app query-and-completion. While not implementing on-device inference or P2P sync, it demonstrates the plugin architecture pattern for local-first tools augmented with LLM capabilities. Relevant as a reference for how local knowledge bases can be retrofitted with AI without cloud dependency (if we swap OpenAI for Cactus).

## Tags

`local-knowledge-management`, `plugin-architecture`, `logseq`, `llm-integration`, `openai-api`

## Topics covered

1. Logseq plugin development pattern
2. OpenAI API integration
3. Local note corpus as context for LLM queries
4. User settings for API configuration

## What we'd take from this

- The plugin seam shape: how Logseq exposes a knowledge corpus to an external LLM layer.
- A working example of bridging a local-first knowledge manager (Logseq) with language models.
- Potential inspiration for recipe-corpus UI if we wanted to build on Logseq instead of a native iOS/Android app (though not our current path).

## Cross-references

- repo-getditto__demoapp-pos-kds (actual Ditto mobile app as better reference for our demo)
