#include <metal_stdlib>
using namespace metal;

constant uint64_t RC[24] = {
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008
};

// Keccak のパーミュテーション関数
void keccak_f(thread uint64_t *state) {
    for (int round = 0; round < 24; round++) {
        uint64_t C[5], D[5];
        for (int i = 0; i < 5; i++) {
            C[i] = state[i] ^ state[i + 5] ^ state[i + 10] ^ state[i + 15] ^ state[i + 20];
        }
        // Theta
        for (int i = 0; i < 5; i++) {
            D[i] = C[(i + 4) % 5] ^ ((C[(i + 1) % 5] << 1) | (C[(i + 1) % 5] >> 63));
        }
        for (int i = 0; i < 25; i++) {
            state[i] ^= D[i % 5];
        }
        
        // Rho and Pi
        uint64_t last = state[1];
        int x = 1, y = 0;
        for (int t = 0; t < 24; t++) {
            int temp = y;
            y = (2 * x + 3 * y) % 5;
            x = temp;
            uint64_t current = state[5 * y + x];
            int shift = ((t + 1) * (t + 2) / 2) % 64;
            state[5 * y + x] = (last << shift) | (last >> (64 - shift));
            last = current;
        }
        
        // Chi
        for (int y = 0; y < 5; y++) {
            for (int x = 0; x < 5; x++) {
                C[x] = state[5 * y + x];
            }
            for (int x = 0; x < 5; x++) {
                state[5 * y + x] ^= (~C[(x + 1) % 5]) & C[(x + 2) % 5];
            }
        }
        uint64_t rc = RC[round];
        state[0] ^= rc;
    }
}

// SHA3-256 ハッシュ関数
void sha3_256(thread const uint8_t *input, thread uint8_t *output) {
    thread uint64_t state[25] = {0};
    
    // Input data XOR into state (safely)
    for (int i = 0; i < 32; i++) {
        int state_idx = i / 8;
        int bit_shift = (7 - (i % 8)) * 8;
        state[state_idx] ^= ((uint64_t)input[i]) << bit_shift;
    }
    
    // Add padding (safely)
    state[4] ^= ((uint64_t)0x06) << 56;  // SHA3 padding at byte 32
    state[16] ^= ((uint64_t)0x80) << 56; // Last byte padding at byte 135
    
    keccak_f(state);
    
    // Output first 32 bytes (256 bits) of state
    for (int i = 0; i < 32; i++) {
        int state_idx = i / 8;
        int bit_shift = (7 - (i % 8)) * 8;
        output[i] = (state[state_idx] >> bit_shift) & 0xFF;
    }
}

kernel void hash_public_key(
    device const uint8_t *public_keys [[buffer(0)]],
    device uint8_t *hashes [[buffer(1)]],
    uint tid [[thread_position_in_grid]]
) {
    // Simple pass-through for testing
    for (int i = 0; i < 32; i++) {
        hashes[tid * 32 + i] = public_keys[tid * 32 + i];
    }
}
