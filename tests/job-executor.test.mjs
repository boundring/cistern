/**
 * v3-core-job-executor — who works where and when.
 *
 * The module under test is src/core/job-executor.ts, imported from the
 * compiled build (out/core/job-executor.js). HNGH_FILL_MODULE points at the
 * file the fill funnel wrote, so the same suite can also run against a
 * workdir copy.
 */

import test from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { pathToFileURL } from "node:url";

const moduleUrl = new URL("../out/core/job-executor.js", import.meta.url);
const modulePath =
  process.env.HNGH_FILL_MODULE && existsSync(process.env.HNGH_FILL_MODULE)
    ? pathToFileURL(process.env.HNGH_FILL_MODULE).href
    : moduleUrl.href;

const {
  JOB_LEGAL_VERBS,
  JOB_UPKEEP_PATIENCE,
  JOB_REFUSED,
  JOB_QUIT,
  JobExecutor,
} = await import(modulePath);

test("the archive constants are the module constants", () => {
  assert.deepEqual(JOB_LEGAL_VERBS, ["wait", "move", "bump", "use_fixture"]);
  assert.equal(JOB_UPKEEP_PATIENCE, 64);
  assert.equal(JOB_REFUSED, "servant/refused");
  assert.equal(JOB_QUIT, "servant/quit");
});

test("an unknown worker cannot be given a job", () => {
  const executor = new JobExecutor();
  const result = executor.assign(99, { verb: "wait" });
  assert.equal(result.ok, false);
  assert.equal(result.message, JOB_REFUSED);
  assert.equal(executor.pending(99), 0);
});

test("an illegal verb is refused", () => {
  const executor = new JobExecutor();
  executor.register(1);
  const result = executor.assign(1, { verb: "dance" });
  assert.equal(result.ok, false);
  assert.equal(result.message, JOB_REFUSED);
  assert.equal(executor.pending(1), 0);
});

test("a legal verb is queued", () => {
  const executor = new JobExecutor();
  executor.register(1);
  const result = executor.assign(1, { verb: "move", dir: "e" });
  assert.equal(result.ok, true);
  assert.equal(executor.pending(1), 1);
});

test("jobs dequeue first in first out", () => {
  const executor = new JobExecutor();
  executor.register(1);
  executor.assign(1, { verb: "move", dir: "e" });
  executor.assign(1, { verb: "move", dir: "w" });
  assert.equal(executor.pending(1), 2);

  const first = executor.act(1);
  assert.equal(first.quit, false);
  assert.deepEqual(first.intent, { verb: "move", dir: "e" });
  assert.equal(executor.pending(1), 1);

  const second = executor.act(1);
  assert.deepEqual(second.intent, { verb: "move", dir: "w" });
  assert.equal(executor.pending(1), 0);
});

test("an empty queue is a wait", () => {
  const executor = new JobExecutor();
  executor.register(1);
  const result = executor.act(1);
  assert.equal(result.quit, false);
  assert.equal(result.intent, undefined);
  assert.equal(executor.unpaidTurns(1), 1);
});

test("the worker quits at the patience limit", () => {
  const executor = new JobExecutor();
  executor.register(1);
  executor.assign(1, { verb: "wait" });

  for (let turn = 0; turn < 63; turn += 1) {
    assert.equal(executor.act(1).quit, false, `turn ${turn + 1}`);
  }
  assert.equal(executor.unpaidTurns(1), 63);

  const last = executor.act(1);
  assert.equal(last.quit, true);
  assert.equal(last.message, JOB_QUIT);
  assert.equal(executor.pending(1), 0);
  assert.equal(executor.unpaidTurns(1), 0);
});

test("payUpkeep clears the counters and keeps the queues", () => {
  const executor = new JobExecutor();
  executor.register(1);
  executor.assign(1, { verb: "wait" });
  executor.assign(1, { verb: "wait" });
  executor.act(1);
  assert.equal(executor.unpaidTurns(1), 1);
  assert.equal(executor.pending(1), 1);

  executor.payUpkeep();
  assert.equal(executor.unpaidTurns(1), 0);
  assert.equal(executor.pending(1), 1);
});

test("an act for an unknown worker does nothing", () => {
  const executor = new JobExecutor();
  const result = executor.act(99);
  assert.equal(result.quit, false);
  assert.equal(result.intent, undefined);
  assert.equal(executor.unpaidTurns(99), 0);
});
