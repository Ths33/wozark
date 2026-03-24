---
name: feedback_deploy_means_push
description: Deploy to CapRover = git push to main. GitHub webhook triggers auto-deploy. Don't use caprover CLI.
type: feedback
---

When user says "deploy" or "faça deploy", it means `git push origin main`. CapRover has a GitHub webhook that auto-deploys on push to main.

**Why:** User got frustrated when Claude tried to use caprover CLI, SSH, and other methods instead of just pushing to GitHub. The deploy pipeline is already set up.

**How to apply:** Deploy = commit + push to main. That's it. Don't try caprover CLI, SSH, or any other method.
