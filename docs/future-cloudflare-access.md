# Future option: Cloudflare Tunnel + Cloudflare Access

> **Not implemented.** This makes the UI reachable from the public internet behind an identity gate. Only do it deliberately.

**Goal:** open `https://ai.yourdomain.com` from any browser, **without Tailscale installed**, after signing in with your identity provider.

## Outline

1. Put a domain on Cloudflare (Cloudflare DNS).
2. In Cloudflare Zero Trust, create a **Tunnel**. Run `cloudflared` as one more service in `docker-compose.yml`, with its token in `.env` and never in git:
   ```yaml
   cloudflared:
     image: cloudflare/cloudflared:latest
     command: tunnel --no-autoupdate run
     environment:
       TUNNEL_TOKEN: ${CLOUDFLARE_TUNNEL_TOKEN}
     restart: unless-stopped
   ```
   Public hostname `ai.yourdomain.com` → service `http://open-webui:8080`. This is an outbound connection only, so there's still no router port forwarding.
3. Create a **Cloudflare Access application** for `ai.yourdomain.com`:
   - Policy: allow only your email address (or Google/GitHub login), with a short session duration.
   - Optionally require MFA and a device posture check.
4. Keep Open WebUI's own login on (two layers). Optionally enable Open WebUI's trusted-header SSO using Access's JWT, but only after validating the JWT.
5. Add the new origin to `WEBUI_URL` / `CORS_ALLOW_ORIGIN`.
6. **Never** route the Ollama API through the tunnel.

## Trade-offs vs. Tailscale

| | Tailscale (current) | Cloudflare Access |
|---|---|---|
| Client needed | Tailscale app | Just a browser |
| Visible to internet | No | Yes (login page at Cloudflare's edge) |
| Traffic path | Device-to-device, WireGuard | Through Cloudflare, which terminates TLS |
| Attack surface | Tailnet members only | Anyone can reach the Access login |

Docs: [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) · [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/applications/)
