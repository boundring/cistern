export type CisternIntent =
  | { readonly kind: "purge"; readonly x: number; readonly y: number }
  | { readonly kind: "buy"; readonly item: string; readonly x: number; readonly y: number };

export const CISTERN_INTENT_KINDS: readonly ["purge", "buy"] = ["purge", "buy"] as const;

export interface IntentView {
  readonly alloy: number;
  readonly purgeRate: number;
  readonly tankLoadAt: (x: number, y: number) => number | undefined;
  readonly priceOf: (item: string) => number | undefined;
  readonly boughtThisCycle: (item: string) => boolean;
}

export interface IntentOutcome {
  readonly ok: boolean;
  readonly reason?: string;
  readonly message?: string;
}

export function parseCisternIntent(text: string): CisternIntent | null {
  const purgeMatch = text.match(/^purge\s+([0-9]+),([0-9]+)\s*$/);
  if (purgeMatch) {
    return {
      kind: "purge",
      x: parseInt(purgeMatch[1], 10),
      y: parseInt(purgeMatch[2], 10),
    };
  }
  const buyMatch = text.match(/^buy\s+(\S+)\s+([0-9]+),([0-9]+)\s*$/);
  if (buyMatch) {
    return {
      kind: "buy",
      item: buyMatch[1],
      x: parseInt(buyMatch[2], 10),
      y: parseInt(buyMatch[3], 10),
    };
  }
  return null;
}

export function describeCisternIntent(intent: CisternIntent): string {
  if (intent.kind === "purge") {
    return `purge ${intent.x},${intent.y}`;
  }
  return `buy ${intent.item} ${intent.x},${intent.y}`;
}

export function checkCisternIntent(intent: CisternIntent, view: IntentView): IntentOutcome {
  if (intent.kind === "purge") {
    const load = view.tankLoadAt(intent.x, intent.y);
    if (load === undefined) {
      return { ok: false, message: "CURSOR NOT ON A TANK" };
    }
    if (load === 0) {
      return { ok: false, message: "TANK ALREADY CLEAR" };
    }
    const recovered = view.purgeRate > 0 ? Math.floor(load / view.purgeRate) : 0;
    return { ok: true, message: `TANK PURGED — RECOVERED ${recovered} ALLOY` };
  }
  if (intent.kind === "buy") {
    const price = view.priceOf(intent.item);
    if (price === undefined) {
      return { ok: false, message: "NO SUCH WARE" };
    }
    if (view.boughtThisCycle(intent.item)) {
      return { ok: false, reason: "shop_sold_out" };
    }
    if (view.alloy < price) {
      return { ok: false, message: `INSUFFICIENT ALLOY — ${price} REQUIRED` };
    }
    return { ok: true, message: "shop/bought" };
  }
  return { ok: false, message: "UNKNOWN INTENT" };
}
