# The demo stack with Docker Compose

Everything from the talk on one laptop: Moodle 5.2 with the OpenTelemetry
extension and both PHP Composer packages, the OpenTelemetry Collector, OpenSearch
and OpenSearch Dashboards. MariaDB is Moodle's database; a small cron loop runs
Moodle cron every minute so scheduled-task traces exist too.

## Requirements

- Docker Engine with the Docker Compose v2 plugin (`docker compose version`), or
  Docker Desktop. Podman with `podman compose` also works.
- About 3 GB of memory for the containers (measured at idle: OpenSearch 1.8 GB,
  the rest under 700 MB together).
- On Linux, OpenSearch needs `vm.max_map_count` of at least 262144:
  `sudo sysctl -w vm.max_map_count=262144`. Docker Desktop sets it for you.

## Start

```bash
cd compose
docker compose up --build
```

The first run builds the Moodle image (PECL compile, Moodle clone, PHP Composer),
which takes 5 to 10 minutes. `moodle-init` then installs the Moodle database
once and exits. When its log says `moodle-init: done`, open:

| What | Where | Login |
|---|---|---|
| Moodle | https://localhost | `admin` / `DemoAdmin2026!` |
| OpenSearch Dashboards | https://localhost:5601 | `admin` / `DemoSearch2026!` |
| OpenSearch itself | https://localhost:9200 | `admin` / `DemoSearch2026!` |

Moodle, OpenSearch and OpenSearch Dashboards use a self-signed certificate
that the `certs` service writes to `compose/certs/` on the first start. The
browser warns once for https://localhost and once for port 5601; accept it. For curl, pass `-k` so it accepts the
self-signed certificate.

Use exactly `https://localhost` for Moodle. Its `wwwroot` is set to that address
and Moodle redirects any other host name.

## First steps in Dashboards

1. Prove data arrived, from a terminal:
   `curl -sk -u admin 'https://localhost:9200/_cat/indices/otel-*?v'`
   (curl asks for the password) — one `otel-v1-logs-moodle-*` index and one
   `otel-v1-apm-span-*` index.
2. Log in to https://localhost:5601. The dashboard "Moodle events" opens at
   once. It shows the last 30 minutes and refreshes itself every 10 seconds.
   `dashboards-init` loaded it at the first start, with the index pattern
   `otel-v1-logs-*`. It has five charts and one list:
   - "Events over time": all events, one point per minute, 0 in quiet minutes.
   - "Logins per minute: success and failure": two lines, one point per minute,
     0 in the minutes with no login.
   - "Totals": the number of events and of different users.
   - "Usernames with the most failed logins": the usernames that were typed.
   - "Event types": the ten most frequent event names.
   - "Latest events": the newest events, with user ID and course ID.

   Log in and out of Moodle, open a course, and type a wrong password ten
   times. The failure line goes up to 10 in that minute, and each click shows
   as a new row in "Latest events". Discover
   (menu → Discover) shows every event; try
   `attributes.event.data.eventname: *user_login_failed*`.
3. Observability → Trace analytics → Traces: the span list. Click one for the
   waterfall. Copy a `traceId` from a log record in Discover to find its request.

The Services page and the service map stay empty here: they need a second
index that only Data Prepper builds, and Data Prepper is not part of this
stack. The trace list and the waterfall do not need it.

## What is where

| File | Role |
|---|---|
| `compose.yaml` | the six components as services, plus MariaDB, cron and four one-shot jobs: `certs`, `opensearch-init`, `dashboards-init`, `moodle-init` |
| `otelcol-config.yaml` | the collector file from the talk (step 8), plus a debug exporter and one trace-only processor (see below) |
| `opensearch/opensearch.yml` | OpenSearch node settings: https, certificate paths, security plugin on |
| `opensearch/internal_users.yml` | the `admin` and `kibanaserver` users with their password hashes |
| `opensearch/opensearch-init.sh` | creates the `otelcol` user and the `otel_collector` role through the security REST API (step 7 of the talk, row one) |
| `opensearch/opensearch_dashboards.yml` | Dashboards: https on 5601, talks to OpenSearch as `kibanaserver`, one shared space (no private tenants) |
| `opensearch/dashboards-init.sh` | loads `moodle-dashboard.ndjson` into Dashboards once, and makes the dashboard the first page after login |
| `opensearch/moodle-dashboard.ndjson` | the index pattern `otel-v1-logs-*`, five charts, one saved search (the list "Latest events") and the dashboard "Moodle events" |
| `opensearch/make-certs.sh` | writes the self-signed CA, node and admin certificates to `certs/` once |
| `moodle-config.php` | Moodle's `config.php`, mounted read-only |
| `moodle-init.sh` | installs the Moodle database once, marker file `.installed` in the data volume |
| `../docker/Dockerfile` | the Moodle image: components 1 to 4 |

The six OpenTelemetry environment variables are in `compose.yaml` under
`x-otel-env`, the same list as step 4 of the talk. Every request is traced:
moodle-package-otel 1.0.1 hard-codes an always-on sampler and ignores
`OTEL_TRACES_SAMPLER`.

## Stop

```bash
docker compose down        # keeps the data volumes
docker compose down -v     # deletes them too
```

## Users and passwords

| User | Password | Where it is used |
|---|---|---|
| `admin` | `DemoSearch2026!` | you, in Dashboards and in curl; `opensearch-init` when it creates the collector's user |
| `otelcol` | `DemoCollector2026!` | the OpenTelemetry Collector, in `otelcol-config.yaml`; may create indices and write documents in `otel-v1-logs-*` and `otel-v1-apm-span-*`, nothing else |
| `kibanaserver` | `DemoDashboards2026!` | OpenSearch Dashboards itself, in `opensearch/opensearch_dashboards.yml` |

The passwords are in the files and in this table on purpose: this is a demo
stack bound to 127.0.0.1. Change all three, and replace the self-signed
certificate, before running any of this where other machines can reach it.

## One processor the talk does not show

`moodle-package-otel` 1.0.1 sets `http.response.status_code` on the root span
of a cron or CLI run from PHP's `http_response_code()`, which returns `false`
outside a web request. After the first web request has made OpenSearch map that
field as a number, every cron root span is rejected with
`mapper_parsing_exception`, and the cron waterfall in Trace analytics has no
root. `otelcol-config.yaml` therefore carries a `transform/cli-status`
processor on the traces pipeline that deletes the attribute when it is `false`.
Source: `vendor/moodlehq/moodle-package-otel/src/Instrumentation/MoodleInstrumentation.php`,
`postShutdownHandler()`.

Verified on 2026-09-02 with Docker 29.1 and Compose 2.39 on Ubuntu 26.04:
plain http on 9200 is refused, https without a password answers 401, the
collector's user cannot read, admin sees both indices, a failed login appeared
in Discover, and a cron run stored a complete trace of 54 spans including its
root.
