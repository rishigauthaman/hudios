# PriceHUD public MT5 backend

This service is the only public endpoint that the app contacts. It is designed
to run behind a cloud provider's managed HTTPS endpoint. The MT5 terminal runs
the separate `scripts/mt5_quote_agent.py` process and pushes prices outward, so
neither a home router port-forward nor a private Wi-Fi address is used.

## Production requirements

1. Deploy the `api` container to a provider with managed HTTPS and a stable
   domain or provider URL.
2. Use a managed PostgreSQL database and set the production `DATABASE_URL`.
   Do not use SQLite in a container deployment.
3. Generate independent 48-byte secrets for `ADMIN_API_KEY`, `AGENT_API_KEY`,
   and `TOKEN_PEPPER`. Keep them in the provider's secret manager, never in
   this repository or in the Android app.
4. Configure the Windows MT5 PC or VPS with `PRICEHUD_API_URL` and
   `PRICEHUD_AGENT_API_KEY`, then run `scripts/mt5_quote_agent.py`.
5. Verify `https://YOUR_API/health` returns `{"status":"ok"}`.
6. Create activation codes only from an administrator terminal:

   ```powershell
   Invoke-RestMethod -Method Post `
     -Uri https://YOUR_API/v1/admin/activation-codes `
     -Headers @{ 'X-Admin-Key' = $env:PRICEHUD_ADMIN_API_KEY } `
     -ContentType 'application/json' `
     -Body '{"max_activations":10,"expires_in_days":30}'
   ```

Give a generated activation code to each authorized user through a secure
channel. The app exchanges it once for a device token held in Android secure
storage. A user can disconnect in the app to revoke its device token.

## Google Cloud Run deployment outline

Cloud Run provides the public HTTPS endpoint, but it cannot run the Windows-only
MT5 terminal. Keep the MT5 publisher on a Windows machine or Windows VPS and
point it at the Cloud Run URL.

1. Create a Google Cloud project with billing, Artifact Registry, Cloud Run,
   Secret Manager, and Cloud SQL for PostgreSQL enabled.
2. Create the Cloud SQL database and a least-privilege `pricehud` database user.
3. Store the database URL and the three random secrets in Secret Manager.
4. Build and deploy `backend/` as a Cloud Run service, attach the Cloud SQL
   instance, and inject those secrets as environment variables. Require HTTPS
   and set a minimum instance only when the desired latency justifies its cost.
5. Give Cloud Run only the permissions needed to access its three secrets and
   Cloud SQL. Put provider rate limiting/WAF rules in front of the service.
6. Set `PRICEHUD_API_URL` to the deployed `https://...run.app` URL and
   `PRICEHUD_AGENT_API_KEY` to the server-side agent secret on the MT5 host.

## Local verification only

Copy `.env.example` to `.env`, fill every secret, add a development-only
`POSTGRES_PASSWORD`, then run `docker compose up --build`. The API will listen
on `http://localhost:8080`; this is intentionally rejected by the mobile app.

## Security boundary

- `POST /v1/agent/quotes` accepts only the server-side agent key.
- `POST /v1/devices/activate` accepts expiring, usage-limited activation codes.
- `GET /v1/quotes/{symbol}` and device deletion require a per-device bearer token.
- Quotes older than `QUOTE_STALE_SECONDS` return HTTP 503 instead of stale data.
- Run the service only over HTTPS in production. Use a cloud firewall/WAF and
  provider rate limiting before opening it to a broad public audience.

## What remains account-specific

Creating a cloud project, accepting its terms, adding payment details, choosing
a domain, and publishing the Play Store listing must be performed by the app
publisher. The repository contains no credentials or billing configuration.
