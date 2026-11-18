[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/rudderstack-1?utm_medium=integration&utm_source=button&utm_campaign=rudderstack)

# Deploy and Host RudderStack on Railway

RudderStack is an open-source customer data platform and Segment alternative. Its server (rudder-server) receives `track`, `identify`, `page` and other events from RudderStack or Segment-compatible SDKs, queues them in Postgres, and delivers them to analytics tools, webhooks and data warehouses, with retries when a destination is down.

## About Hosting RudderStack

This template runs the RudderStack data plane: rudder-server 1.93.0 (public, port 8080), rudder-transformer 1.169.0 (private) and Railway Postgres as the durable job queue. rudder-server's working files sit on a volume. The deploy asks for nothing. It starts in standalone mode with one HTTP source and a generated write key (the `RUDDER_WRITE_KEY` variable on rudder-server). Set `RUDDER_WEBHOOK_URL` to forward every event to a webhook. For RudderStack's 200+ destinations and its dashboard, create a free RudderStack Open Source workspace, generate a workspace token and set `WORKSPACE_TOKEN`: the server then reads sources and destinations from RudderStack's hosted control plane.

## Common Use Cases

* Collect product events from websites and apps without sending them to a third-party collector
* Replace Segment with Segment-compatible SDKs and a self-hosted endpoint
* Forward events to webhooks, analytics tools and warehouses with retries and a durable queue

## Dependencies for RudderStack Hosting

* Postgres (bundled: Railway Postgres, used as the job queue)
* rudder-transformer (bundled, private network only)

### Deployment Dependencies

* [RudderStack Open Source docs](https://www.rudderstack.com/docs/get-started/rudderstack-open-source/)
* [rudder-server releases](https://github.com/rudderlabs/rudder-server/releases) and [rudder-transformer releases](https://github.com/rudderlabs/rudder-transformer/releases)
* Template repo: [aalfath/rudderstack-railway-template](https://github.com/aalfath/rudderstack-railway-template)
* Optional: a free [RudderStack Open Source](https://app.rudderstack.com/signup?type=opensource) workspace for the hosted control plane (`WORKSPACE_TOKEN`)

### Implementation Details

After the deploy, copy `RUDDER_WRITE_KEY` from the rudder-server service's variables and send a test event (the write key is the Basic-auth user, with an empty password):

```bash
curl -u "YOUR-WRITE-KEY:" -H "Content-Type: application/json" \
  https://YOUR-DOMAIN/v1/track \
  -d '{"userId":"user-1","event":"Signed Up","properties":{"plan":"free"}}'
```

Point SDKs at `https://YOUR-DOMAIN` as the data plane URL. `GET /health` shows the server and database status.

* **Standalone mode (default):** sources and destinations come from a workspace config generated on each start at `/data/workspaceConfig.json`: one HTTP source with `RUDDER_WRITE_KEY` and, if `RUDDER_WEBHOOK_URL` is set, one Webhook destination. To use your own config file instead, write it to `/data/workspaceConfig.json` and set `RUDDER_CONFIG_FILE_MANAGED=true`.
* **Control plane mode:** set `WORKSPACE_TOKEN` (Settings > Workspace > Security in the RudderStack dashboard) and redeploy. In that mode the write keys come from your RudderStack sources.
* **Licence:** rudder-server and rudder-transformer are under the Elastic License 2.0 (source-available; self-hosting for your own use is allowed).
* **Updates:** both services build from the template repo, which pins the official images by version and digest. When the repo moves to a new release, Railway shows an update notice on your project; check `CHANGELOG.md` before you apply it. RudderStack requires matching server and transformer versions, so both are updated together.

## Why Deploy RudderStack on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying RudderStack on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
