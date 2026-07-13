# ADR-0002 — Synchronous, idempotent video processing

Status: accepted

## Context

The video-processor originally handled `video.upload.completed` by dispatching the work
to a Spring `@Async` executor and returning immediately. Because the shared messaging
library acknowledges messages in `AUTO` mode, the broker acked the message **before** the
ffmpeg work ran. A pod crash (or shutdown draining the async queue) then lost the video
with no redelivery, and the whole method ran inside a single long-lived `@Transactional`,
holding one DB connection for the entire job and publishing events inside the transaction.

A reader would reasonably assume async processing is the right choice for a long CPU-bound
job, so the decision to make it synchronous needs to be recorded.

## Decision

Process the video **synchronously on the RabbitMQ listener thread** and remove `@Async`
/ `@EnableAsync`:

- The message is acknowledged only **after** processing completes, so a crash leaves it
  unacknowledged → redelivery (at-least-once); after retries it goes to the DLQ.
- Each state transition (`PENDING → PROCESSING → COMPLETED/FAILED`) is its own short
  transaction — no minutes-long connection, no Hikari pool exhaustion.
- Processing is **idempotent per `uploadId`** (unique in the DB): a redelivered or
  reconciler-replayed event for an already-`COMPLETED` upload is skipped; any other prior
  state is reprocessed on the same job row.

Concurrency (to satisfy *"processar mais de um vídeo ao mesmo tempo"*) comes from three
independent axes instead of a fire-and-forget executor: **listener consumers per pod**
(shared-lib `rabbit.topic.concurrent-consumers`, default 2), **pods per node**, and
**pod count** via a CPU-based HPA (2→4).

## Consequences

- Delivery guarantee changes from at-most-once (lossy) to at-least-once; consumers must
  be idempotent — which the `uploadId` uniqueness enforces.
- Per-pod throughput is bounded by consumer concurrency rather than an unbounded thread
  pool, which is the intended back-pressure on CPU-bound ffmpeg work (t3.medium = 2 vCPU).
- Requires the reconciler in [ADR-0001](0001-ephemeral-broker-application-durability.md)
  to replay events safely.
