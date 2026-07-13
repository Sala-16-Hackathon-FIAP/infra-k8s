# ADR-0001 — Ephemeral broker with application-level durability

Status: accepted

## Context

The AWS Academy environment has no EBS CSI driver, so the RabbitMQ Helm release runs
with `persistence.enabled=false` and a single replica. A broker restart therefore drops
all queued and in-flight messages. The functional requirement is explicit that *"em caso
de picos, o sistema não deve perder uma requisição"*, so we cannot rely on the broker to
not lose messages.

## Decision

Treat the broker as a **best-effort transport, not a durable log**, and guarantee
delivery in the application instead:

1. The upload is persisted to S3 **and** PostgreSQL **before** `video.upload.completed`
   is published — the database, not the queue, is the source of truth.
2. Processing is **at-least-once** (consume-then-ack on the worker thread; redelivery on
   crash; per-queue DLQ after retries) and **idempotent per `uploadId`** — see ADR-0002.
3. A **reconciler** in the upload-service re-publishes `video.upload.completed` for
   uploads that completed but were never acknowledged by the processor within a stale
   threshold, bounded by a max-attempts counter.

## Considered options

- **Durable RabbitMQ (persistent volume + quorum queues).** Rejected: the Academy
  cluster cannot mount persistent volumes (no EBS CSI addon) and cannot run a
  multi-node quorum cheaply. Not available in this environment.
- **Amazon SQS / managed durable broker.** Rejected: adds a managed dependency and IAM
  wiring outside the Academy constraints and the chosen self-hosted stack.
- **Accept message loss.** Rejected: violates the "não perder requisição" requirement.

## Consequences

- Correctness does not depend on broker durability; the system self-heals after a broker
  restart within one reconciliation cycle.
- Extra bookkeeping in the upload-service (`processing_started_at`, `reconciliation_attempts`)
  and a scheduled job.
- If the environment later gains persistent volumes, enabling broker durability is
  complementary and would reduce reconciler activity — the safety net can stay.
