# Laptop setup

The laptop only runs a browser and Tailscale. The model runs on the desktop.

1. **Install Tailscale** from https://tailscale.com/download, or on Windows:
   ```powershell
   winget install -e --id Tailscale.Tailscale
   ```
2. **Sign in to Tailscale** with the same account the desktop uses. The laptop then appears under Machines in the [admin console](https://login.tailscale.com/admin/machines).
3. **Open and bookmark:**

   ## https://ai-desktop.tailXXXXXX.ts.net

4. Sign in with your Open WebUI account, pick a model (`qwen2.5-coder:14b` for code), and chat.
5. **Also bookmark the repo agent (OpenHands):**

   ## https://ai-desktop.tailXXXXXX.ts.net:8443

   No separate login: access is tied to your Tailscale identity. First time: add a GitHub token under Settings → Integrations ([agent-harness.md](agent-harness.md)), then choose a repo and branch → Launch.

## Important

- **`localhost` on the laptop means the laptop**, not the desktop. `http://localhost:3000` only works when you're sitting at the desktop.
- Tailscale must be **connected** on the laptop. If the bookmark doesn't load, check the Tailscale tray icon first.
- This works from anywhere with internet access (home, café, phone hotspot). There's nothing to configure on your router.
- Phones work too: install the Tailscale app, sign in with the same account, and open the same address.
