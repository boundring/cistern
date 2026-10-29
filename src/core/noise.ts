/**
 * Godot's FastNoiseLite (thirdparty/misc/FastNoiseLite.h, v1.1.0, as shipped
 * in Godot 4.7.2), restricted to the path the donor's world law uses:
 * noise_type = TYPE_SIMPLEX_SMOOTH (NoiseType_OpenSimplex2S), fractal_type =
 * FRACTAL_FBM, lacunarity 2.0, gain 0.5, weighted strength 0, no offset, no
 * domain warp. Godot's engine computes in 32-bit floats; every float32
 * operation below is reproduced with Math.fround at the same point, so the
 * port is bit-exact against `godot --headless` probes.
 *
 * Note: Godot 4.7.2's FastNoiseLite has NO permutation table — gradient
 * lookup is a prime-hash (Hash/GradCoord), ported verbatim.
 */

export interface NoiseOptions {
  seed: number; // Godot FastNoiseLite seed (0..2147483647)
  frequency: number; // cycles per unit, as the donor sets it (1.0/45.0 etc.)
  octaves: number; // fractal octaves (FBM)
}

const f = Math.fround;

const SQRT3 = f(1.7320508075688772935274463415059);
// TransformNoiseCoordinate: F2 = 0.5f * (SQRT3 - 1)
const F2 = f(f(SQRT3 - 1) * 0.5);
// SingleOpenSimplex2S: G2 = (3 - SQRT3) / 6
const G2 = f(f(3 - SQRT3) / 6);
const TWO_THIRDS = f(2 / 3);
// (float)(1 - 2 * G2)
const M1 = f(1 - f(2 * G2));
// (float)(2 * (1 - 2 * G2) * (1 / G2 - 2))
const A1_COEF = f(f(2 * M1) * f(f(1 / G2) - 2));
// (float)(-2 * (1 - 2 * G2) * (1 - 2 * G2))
const A1_NEG = f(f(-2 * M1) * M1);
// (float)(3 * G2 - 2), (float)(3 * G2 - 1), (float)(G2 - 1), (float)(1 - G2)
const C3G2_2 = f(f(3 * G2) - 2);
const C3G2_1 = f(f(3 * G2) - 1);
const CG2_M1 = f(G2 - 1);
const C1_M_G2 = f(1 - G2);
// Final scale of SingleOpenSimplex2S.
const SCALE = f(18.24196194486065);
// Donor defaults: FBM lacunarity/gain; weighted strength 0 (amp *= Lerp(1, .., 0) === 1).
const LACUNARITY = 2;
const GAIN = 0.5;

const PRIME_X = 501125321;
const PRIME_Y = 1136930381;
const HASH_MULTIPLIER = 0x27d4eb2d;

// Lookup<float>::Gradients2D, verbatim (128 unit gradients; hash & (127 << 1) indexes pairs).
const GRADIENTS_2D = new Float32Array([
  0.130526185, 0.991444886, 0.382683426, 0.923879504, 0.60876143, 0.793353319, 0.793353319, 0.60876143,
  0.923879504, 0.382683426, 0.991444886, 0.130526185, 0.991444886, -0.130526185, 0.923879504, -0.382683426,
  0.793353319, -0.60876143, 0.60876143, -0.793353319, 0.382683426, -0.923879504, 0.130526185, -0.991444886,
  -0.130526185, -0.991444886, -0.382683426, -0.923879504, -0.60876143, -0.793353319, -0.793353319, -0.60876143,
  -0.923879504, -0.382683426, -0.991444886, -0.130526185, -0.991444886, 0.130526185, -0.923879504, 0.382683426,
  -0.793353319, 0.60876143, -0.60876143, 0.793353319, -0.382683426, 0.923879504, -0.130526185, 0.991444886,
  0.130526185, 0.991444886, 0.382683426, 0.923879504, 0.60876143, 0.793353319, 0.793353319, 0.60876143,
  0.923879504, 0.382683426, 0.991444886, 0.130526185, 0.991444886, -0.130526185, 0.923879504, -0.382683426,
  0.793353319, -0.60876143, 0.60876143, -0.793353319, 0.382683426, -0.923879504, 0.130526185, -0.991444886,
  -0.130526185, -0.991444886, -0.382683426, -0.923879504, -0.60876143, -0.793353319, -0.793353319, -0.60876143,
  -0.923879504, -0.382683426, -0.991444886, -0.130526185, -0.991444886, 0.130526185, -0.923879504, 0.382683426,
  -0.793353319, 0.60876143, -0.60876143, 0.793353319, -0.382683426, 0.923879504, -0.130526185, 0.991444886,
  0.130526185, 0.991444886, 0.382683426, 0.923879504, 0.60876143, 0.793353319, 0.793353319, 0.60876143,
  0.923879504, 0.382683426, 0.991444886, 0.130526185, 0.991444886, -0.130526185, 0.923879504, -0.382683426,
  0.793353319, -0.60876143, 0.60876143, -0.793353319, 0.382683426, -0.923879504, 0.130526185, -0.991444886,
  -0.130526185, -0.991444886, -0.382683426, -0.923879504, -0.60876143, -0.793353319, -0.793353319, -0.60876143,
  -0.923879504, -0.382683426, -0.991444886, -0.130526185, -0.991444886, 0.130526185, -0.923879504, 0.382683426,
  -0.793353319, 0.60876143, -0.60876143, 0.793353319, -0.382683426, 0.923879504, -0.130526185, 0.991444886,
  0.130526185, 0.991444886, 0.382683426, 0.923879504, 0.60876143, 0.793353319, 0.793353319, 0.60876143,
  0.923879504, 0.382683426, 0.991444886, 0.130526185, 0.991444886, -0.130526185, 0.923879504, -0.382683426,
  0.793353319, -0.60876143, 0.60876143, -0.793353319, 0.382683426, -0.923879504, 0.130526185, -0.991444886,
  -0.130526185, -0.991444886, -0.382683426, -0.923879504, -0.60876143, -0.793353319, -0.793353319, -0.60876143,
  -0.923879504, -0.382683426, -0.991444886, -0.130526185, -0.991444886, 0.130526185, -0.923879504, 0.382683426,
  -0.793353319, 0.60876143, -0.60876143, 0.793353319, -0.382683426, 0.923879504, -0.130526185, 0.991444886,
  0.130526185, 0.991444886, 0.382683426, 0.923879504, 0.60876143, 0.793353319, 0.793353319, 0.60876143,
  0.923879504, 0.382683426, 0.991444886, 0.130526185, 0.991444886, -0.130526185, 0.923879504, -0.382683426,
  0.793353319, -0.60876143, 0.60876143, -0.793353319, 0.382683426, -0.923879504, 0.130526185, -0.991444886,
  -0.130526185, -0.991444886, -0.382683426, -0.923879504, -0.60876143, -0.793353319, -0.793353319, -0.60876143,
  -0.923879504, -0.382683426, -0.991444886, -0.130526185, -0.991444886, 0.130526185, -0.923879504, 0.382683426,
  -0.793353319, 0.60876143, -0.60876143, 0.793353319, -0.382683426, 0.923879504, -0.130526185, 0.991444886,
  0.382683426, 0.923879504, 0.923879504, 0.382683426, 0.923879504, -0.382683426, 0.382683426, -0.923879504,
  -0.382683426, -0.923879504, -0.923879504, -0.382683426, -0.923879504, 0.382683426, -0.382683426, 0.923879504,
]);

/** GradCoord(seed, xPrimed, yPrimed, xd, yd) in float32. */
function gradCoord(seed: number, xPrimed: number, yPrimed: number, xd: number, yd: number): number {
  // Hash(seed, xPrimed, yPrimed): signed int32, as C++ int wraparound.
  let h = Math.imul((seed ^ xPrimed ^ yPrimed) | 0, HASH_MULTIPLIER);
  h = (h ^ (h >> 15)) & (127 << 1);
  return f(f(xd * GRADIENTS_2D[h]) + f(yd * GRADIENTS_2D[h | 1]));
}

/** a = (2/3) - x*x - y*y, float32 per operation. */
function falloff(x2: number, y2: number): number {
  return f(f(TWO_THIRDS - f(x2 * x2)) - f(y2 * y2));
}

/** (a*a) * (a*a) * GradCoord(...), float32 per operation. */
function ridgeTerm(a: number, seed: number, xp: number, yp: number, xd: number, yd: number): number {
  const sq = f(a * a);
  return f(f(sq * sq) * gradCoord(seed, xp, yp, xd, yd));
}

/**
 * SingleOpenSimplex2S(seed, x, y) — the 2D smooth simplex of the donor's
 * TYPE_SIMPLEX_SMOOTH, with the skew already applied by getNoise2D (moved to
 * TransformNoiseCoordinate upstream). Coordinates enter as float32.
 */
function singleOpenSimplex2S(seed: number, x: number, y: number): number {
  const i = fastFloor(x);
  const j = fastFloor(y);
  const xi = f(x - i);
  const yi = f(y - j);

  const pi = Math.imul(i, PRIME_X);
  const pj = Math.imul(j, PRIME_Y);
  const pi1 = (pi + PRIME_X) | 0;
  const pj1 = (pj + PRIME_Y) | 0;

  const t = f(f(xi + yi) * G2);
  const x0 = f(xi - t);
  const y0 = f(yi - t);

  const a0 = falloff(x0, y0);
  let value = ridgeTerm(a0, seed, pi, pj, x0, y0);

  const a1 = f(f(A1_COEF * t) + f(A1_NEG + a0));
  const x1 = f(x0 - M1);
  const y1 = f(y0 - M1);
  value = f(value + ridgeTerm(a1, seed, pi1, pj1, x1, y1));

  const xmyi = f(xi - yi);
  if (t > G2) {
    if (f(xi + xmyi) > 1) {
      const x2 = f(x0 + C3G2_2);
      const y2 = f(y0 + C3G2_1);
      const a2 = falloff(x2, y2);
      if (a2 > 0) {
        value = f(value + ridgeTerm(a2, seed, (pi + (PRIME_X << 1)) | 0, (pj + PRIME_Y) | 0, x2, y2));
      }
    } else {
      const x2 = f(x0 + G2);
      const y2 = f(y0 + CG2_M1);
      const a2 = falloff(x2, y2);
      if (a2 > 0) {
        value = f(value + ridgeTerm(a2, seed, pi, (pj + PRIME_Y) | 0, x2, y2));
      }
    }

    if (f(yi - xmyi) > 1) {
      const x3 = f(x0 + C3G2_1);
      const y3 = f(y0 + C3G2_2);
      const a3 = falloff(x3, y3);
      if (a3 > 0) {
        value = f(value + ridgeTerm(a3, seed, (pi + PRIME_X) | 0, (pj + (PRIME_Y << 1)) | 0, x3, y3));
      }
    } else {
      const x3 = f(x0 + CG2_M1);
      const y3 = f(y0 + G2);
      const a3 = falloff(x3, y3);
      if (a3 > 0) {
        value = f(value + ridgeTerm(a3, seed, (pi + PRIME_X) | 0, pj, x3, y3));
      }
    }
  } else {
    if (f(xi + xmyi) < 0) {
      const x2 = f(x0 + C1_M_G2);
      const y2 = f(y0 - G2);
      const a2 = falloff(x2, y2);
      if (a2 > 0) {
        value = f(value + ridgeTerm(a2, seed, (pi - PRIME_X) | 0, pj, x2, y2));
      }
    } else {
      const x2 = f(x0 + CG2_M1);
      const y2 = f(y0 + G2);
      const a2 = falloff(x2, y2);
      if (a2 > 0) {
        value = f(value + ridgeTerm(a2, seed, (pi + PRIME_X) | 0, pj, x2, y2));
      }
    }

    if (yi < xmyi) {
      const x2 = f(x0 - G2);
      const y2 = f(y0 - CG2_M1);
      const a2 = falloff(x2, y2);
      if (a2 > 0) {
        value = f(value + ridgeTerm(a2, seed, pi, (pj - PRIME_Y) | 0, x2, y2));
      }
    } else {
      const x2 = f(x0 + G2);
      const y2 = f(y0 + CG2_M1);
      const a2 = falloff(x2, y2);
      if (a2 > 0) {
        value = f(value + ridgeTerm(a2, seed, pi, (pj + PRIME_Y) | 0, x2, y2));
      }
    }
  }

  return f(value * SCALE);
}

/** FastFloor: C's (int) truncation toward zero, then subtract below zero. */
function fastFloor(v: number): number {
  return v >= 0 ? v | 0 : (v | 0) - 1;
}

export class FastNoiseLite {
  private readonly seed: number;
  private readonly frequency: number;
  private readonly octaves: number;
  private readonly fractalBounding: number;

  constructor(opts: NoiseOptions) {
    this.seed = opts.seed | 0;
    this.frequency = f(opts.frequency); // Godot real_t member
    this.octaves = opts.octaves;

    // CalculateFractalBounding in float32 (gain 0.5).
    const gain = Math.abs(GAIN);
    let amp = f(gain);
    let ampFractal = 1;
    for (let i = 1; i < this.octaves; i++) {
      ampFractal = f(ampFractal + amp);
      amp = f(amp * gain);
    }
    this.fractalBounding = f(1 / ampFractal);
  }

  /** Godot get_noise_2d(x, y) -> [-1, 1]; float32-identical to the donor. */
  getNoise2D(x: number, y: number): number {
    // Godot's wrapper receives real_t (float32) coordinates.
    x = f(x);
    y = f(y);

    // TransformNoiseCoordinate: x *= mFrequency, then OpenSimplex2S skew.
    x = f(x * this.frequency);
    y = f(y * this.frequency);
    const t = f(f(x + y) * F2);
    x = f(x + t);
    y = f(y + t);

    // GenFractalFBm: per-octave seed++, weighted strength 0 (amp update is a no-op).
    let seed = this.seed;
    let sum = 0;
    let amp = this.fractalBounding;
    for (let i = 0; i < this.octaves; i++) {
      sum = f(sum + f(singleOpenSimplex2S(seed, x, y) * amp));
      seed = (seed + 1) | 0;
      x = f(x * LACUNARITY);
      y = f(y * LACUNARITY);
      amp = f(amp * GAIN);
    }
    return sum;
  }
}
