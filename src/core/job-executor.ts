export const JOB_LEGAL_VERBS: readonly ["wait", "move", "bump", "use_fixture"] = ["wait", "move", "bump", "use_fixture"];
export const JOB_UPKEEP_PATIENCE: number = 64;
export const JOB_REFUSED: string = "servant/refused";
export const JOB_QUIT: string = "servant/quit";

export type JobVerb = "wait" | "move" | "bump" | "use_fixture";

export interface JobIntent {
  readonly verb: JobVerb;
  readonly dir?: string;
  readonly row?: number;
}

export interface JobAssign {
  readonly ok: boolean;
  readonly message?: string;
}

export interface JobOutcome {
  readonly quit: boolean;
  readonly intent?: JobIntent;
  readonly message?: string;
}

interface WorkerState {
    queue: JobIntent[];
    unpaidTurns: number;
}

export class JobExecutor {
    private workers: Map<number, WorkerState> = new Map();

    register(id: number): void {
        if (!this.workers.has(id)) {
            this.workers.set(id, {
                queue: [],
                unpaidTurns: 0,
            });
        }
    }

    private getWorkerState(id: number): WorkerState | undefined {
        return this.workers.get(id);
    }

    assign(id: number, intent: JobIntent): JobAssign {
        const worker = this.getWorkerState(id);

        if (!worker) {
            return { ok: false, message: JOB_REFUSED };
        }

        if (!JOB_LEGAL_VERBS.includes(intent.verb)) {
            return { ok: false, message: JOB_REFUSED };
        }

        worker.queue.push(intent);
        return { ok: true };
    }

    payUpkeep(): void {
        for (const worker of this.workers.values()) {
            worker.unpaidTurns = 0;
        }
    }

    act(id: number): JobOutcome {
        const worker = this.getWorkerState(id);

        if (!worker) {
            return { quit: false };
        }

        worker.unpaidTurns += 1;

        if (worker.unpaidTurns === JOB_UPKEEP_PATIENCE) {
            worker.queue = [];
            worker.unpaidTurns = 0;
            return { quit: true, message: JOB_QUIT };
        }

        if (worker.queue.length > 0) {
            const intent = worker.queue.shift()!;
            return { quit: false, intent: intent };
        } else {
            return { quit: false, intent: undefined };
        }
    }

    pending(id: number): number {
        const worker = this.getWorkerState(id);
        return worker ? worker.queue.length : 0;
    }

    unpaidTurns(id: number): number {
        const worker = this.getWorkerState(id);
        return worker ? worker.unpaidTurns : 0;
    }
}
