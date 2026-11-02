export const SHOP_ITEMS: readonly ["toilet", "pipe", "tank", "decon", "clear"] = [
  "toilet",
  "pipe",
  "tank",
  "decon",
  "clear",
] as const;

export type ShopItem = "toilet" | "pipe" | "tank" | "decon" | "clear";

export const SHOP_PRICE: Readonly<Record<ShopItem, number>> = {
  toilet: 10,
  pipe: 2,
  tank: 15,
  decon: 3,
  clear: 2,
};

export const RESTOCK_TICKS: number = 100;

export interface Purchase {
  readonly turn: number;
  readonly item: ShopItem;
}

export interface ShopStock {
  readonly purchases: Purchase[];
}

export function createShopStock(): ShopStock {
  return { purchases: [] };
}

export function restockCycle(turn: number): number {
  return Math.floor(turn / RESTOCK_TICKS);
}

export function boughtThisCycle(stock: ShopStock, item: ShopItem, turn: number): boolean {
  const cycle = restockCycle(turn);
  return stock.purchases.some(
    (p) => p.item === item && restockCycle(p.turn) === cycle
  );
}

export function recordPurchase(stock: ShopStock, item: ShopItem, turn: number): void {
  stock.purchases.push({ turn, item });
}

export function buyItem(
  stock: ShopStock,
  item: ShopItem,
  turn: number,
  alloy: number,
): { stock: ShopStock; alloy: number; ok: boolean; reason?: "sold_out" | "too_poor" } {
  if (boughtThisCycle(stock, item, turn)) {
    return { stock, alloy, ok: false, reason: "sold_out" };
  }

  const price = SHOP_PRICE[item];
  if (alloy < price) {
    return { stock, alloy, ok: false, reason: "too_poor" };
  }

  const newStock: ShopStock = {
    purchases: [...stock.purchases, { turn, item }],
  };
  return { stock: newStock, alloy: alloy - price, ok: true };
}
