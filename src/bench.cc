#include <algorithm>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <vector>
#include <unistd.h>

#include "decl.h"
#include "timer_utils.h"
#include "utils.h"

////////////////////////////////////////////////////////////////////////////////
// This is a small program that compares two memset implementations and records
// the output in a csv file.
////////////////////////////////////////////////////////////////////////////////

#define ITER (1000L * 1000L * 100L)
#define SAMPLES (10)

uint64_t measure(memset_ty handle, unsigned samples, unsigned size,
                 unsigned align, unsigned offset, void *ptr) {
  std::vector<uint64_t> tv;
  for (unsigned i = 0; i < samples; i++) {
    Stopwatch T;
    for (size_t i = 0; i < ITER; i++) {
      (handle)(ptr, 0, size);
    }
    tv.push_back(T.getTimeDelta());
  }
  std::sort(tv.begin(), tv.end());
  // Return the median of the samples.
  return tv[tv.size() / 2];
}

// Allocate memory and benchmark a single implementation.
void bench_impl(memset_ty handle0, memset_ty handle1, unsigned size,
                unsigned align, unsigned offset) {
  std::cout << size << ", " << align << ", " << offset << ", ";

  std::vector<char> memory(size + 256, 0);
  void *ptr = align_pointer(&memory[0], align, offset);
  u_int64_t t0 = measure(handle0, SAMPLES, size, align, offset, ptr);
  u_int64_t t1 = measure(handle1, SAMPLES, size, align, offset, ptr);
  std::cout << t0 << ", " << t1 << ", " << (double)t0 / t1 << "," << std::endl;
}

int main(int argc, char **argv) {
  std::cout << std::setprecision(3);
  std::cout << std::fixed << "size, alignment, offset, libc, local\n";

  for (int i = 0; i < 512; i++) {
    bench_impl(libc_memset, local_memset, i, 16, 0);
  }

  return 0;
}
