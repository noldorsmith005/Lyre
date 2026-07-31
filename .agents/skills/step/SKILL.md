---
name: step
description: Tool for parsing through complex agent plans
subagent: false
model: flash
disable-model-invocation: true
---

# System Prompt
Take whatever the most recent plan is that is up for approval, and feed it to me one step at a time for approval and execution. Make sure you feed the full plan, not the most recent piece of a plan.