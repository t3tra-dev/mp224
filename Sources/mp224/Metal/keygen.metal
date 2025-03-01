#include <metal_stdlib>
using namespace metal;

// 定数定義
[[maybe_unused]] constant uint64_t D_H = 0x52036CEE2B6FFE73;  // 上位 64 ビット
constant uint64_t D_L = 0x8CC740797779E898;  // 下位 64 ビット
constant uint64_t Q_H = 0x7FFFFFFFFFFFFFFF;  // 上位 64 ビット
constant uint64_t Q_L = 0xFFFFFFFFFFFFFFFF;  // 下位 64 ビット - 19 は後で調整
[[maybe_unused]] constant uint64_t L_H = 0x1000000000000000;  // 上位 64 ビット
[[maybe_unused]] constant uint64_t L_L = 0x000000014DEF9DEA;  // 下位 64 ビット

struct uint128_t {
    uint64_t hi;
    uint64_t lo;
};

// 64 ビット整数の乗算（128 ビットの結果を返す）
uint128_t mul64(uint64_t a, uint64_t b) {
    uint64_t a_lo = a & 0xFFFFFFFF;
    uint64_t a_hi = a >> 32;
    uint64_t b_lo = b & 0xFFFFFFFF;
    uint64_t b_hi = b >> 32;

    uint64_t p0 = a_lo * b_lo;
    uint64_t p1 = a_lo * b_hi;
    uint64_t p2 = a_hi * b_lo;
    uint64_t p3 = a_hi * b_hi;

    uint64_t carry = (p0 >> 32) + (p1 & 0xFFFFFFFF) + (p2 & 0xFFFFFFFF);
    uint64_t lo = (carry << 32) | (p0 & 0xFFFFFFFF);
    uint64_t hi = (p1 >> 32) + (p2 >> 32) + (p3) + (carry >> 32);

    return (uint128_t){hi, lo};
}

// 128 ビット整数の加算
uint128_t add128(uint128_t a, uint128_t b) {
    uint128_t result;
    result.lo = a.lo + b.lo;
    result.hi = a.hi + b.hi + (result.lo < a.lo);
    return result;
}

// 128 ビット整数を 64 ビットに割る
uint64_t mod128(uint128_t a, uint64_t m) {
    return ((a.hi % m) * (0xFFFFFFFFFFFFFFFF % m) + a.lo % m) % m;
}

// 128ビット整数のモジュラー逆元（Fermat の小定理を使用）
uint64_t inv(uint64_t x) {
    uint64_t r = 1;
    uint128_t e = {Q_H, Q_L - 2}; // q - 2 を 128 ビットとして表現
    while (e.hi > 0 || e.lo > 0) {
        if (e.lo & 1) {
            r = mod128(mul64(r, x), Q_L);
        }
        x = mod128(mul64(x, x), Q_L);
        e.lo >>= 1;
        if (e.hi & 1) e.lo |= (1ull << 63);
        e.hi >>= 1;
    }
    return r;
}

uint64_t xrecover(uint64_t y) {
    uint128_t xx = mul64(y, y);
    xx = add128(xx, (uint128_t){0, 0xFFFFFFFFFFFFFFFF}); // y^2 - 1 を uint64_t の最大値として表現
    xx = mul64(xx.lo, inv(mul64(y, y).lo + 1)); // (y^2 - 1) * inv(d*y^2 + 1)

    uint64_t x = xx.lo;
    for (int i = 0; i < 4; i++) {
        x = mod128(mul64(x, x), Q_L);
    }

    if (mod128(mul64(x, x), Q_L) != xx.lo) {
        x = mod128(mul64(x, 2), Q_L);
    }
    if (x % 2 != 0) x = Q_L - x;
    return x;
}

// Edwards曲線の加算
void edwards(thread uint64_t *P, thread uint64_t *Q, thread uint64_t *result) {
    uint64_t x1 = P[0], y1 = P[1];
    uint64_t x2 = Q[0], y2 = Q[1];

    uint64_t x3 = ((x1 * y2 + x2 * y1) * inv(1 + D_L * x1 * x2 * y1 * y2)) % Q_L;
    uint64_t y3 = ((y1 * y2 + x1 * x2) * inv(1 - D_L * x1 * x2 * y1 * y2)) % Q_L;

    result[0] = x3;
    result[1] = y3;
}

void scalarmult(thread uint64_t *P, uint64_t e, thread uint64_t *result) {
    thread uint64_t R0[2] = {0, 1};
    thread uint64_t R1[2] = {P[0], P[1]};

    for (int i = 254; i >= 0; i--) {
        if ((e >> i) & 1) {
            edwards(R0, R1, R0);
            edwards(R1, R1, R1);
        } else {
            edwards(R1, R0, R1);
            edwards(R0, R0, R0);
        }
    }
    result[0] = R0[0];
    result[1] = R0[1];
}

kernel void generate_public_key(device const uint8_t *seeds [[buffer(0)]],
                         device uint8_t *public_keys [[buffer(1)]],
                         uint tid [[thread_position_in_grid]]) {
    
    uint64_t secret_key_hi = 0;
    uint64_t secret_key_lo = 0;
    for (int i = 0; i < 16; i++) {
        if (i < 8) {
            secret_key_hi = (secret_key_hi << 8) | seeds[tid * 32 + i];
        } else {
            secret_key_lo = (secret_key_lo << 8) | seeds[tid * 32 + i];
        }
    }
    uint64_t secret_key = secret_key_lo; // Use lower 64 bits for now
    
    uint64_t B[2] = {xrecover(4 * inv(5)), 4 * inv(5)};
    thread uint64_t pub_key[2];
    
    scalarmult(B, secret_key, pub_key);
    
    // 公開鍵をバイト配列に変換（32バイト全体を使用）
    uint64_t x = pub_key[0];
    uint64_t y = pub_key[1];
    
    for (int i = 0; i < 16; i++) {
        public_keys[tid * 32 + i] = (x >> (56 - (i * 8))) & 0xFF;
        public_keys[tid * 32 + 16 + i] = (y >> (56 - (i * 8))) & 0xFF;
    }
}
