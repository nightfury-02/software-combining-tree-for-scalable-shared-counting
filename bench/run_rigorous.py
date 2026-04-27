import subprocess
import re
from collections import defaultdict

NUM_RUNS = 5
results = defaultdict(lambda: {"throughput": [], "latency": []})

print(f"Running benchmarks {NUM_RUNS} times to compute averages...\n")

for i in range(NUM_RUNS):
    print(f"Executing run {i + 1}/{NUM_RUNS}...")
    res = subprocess.run(["./_build/default/bench/bench_main.exe"], capture_output=True, text=True)
    
    # Parse lines like: "  [Running] Atomic FAA      | 2          => Throughput: 16168006             | Latency: 75.50"
    for line in res.stdout.split("\n"):
        match = re.search(r"\[Running\]\s+(.*?)\s+\|\s+(\d+)\s+=> Throughput:\s+(\d+)\s+\|\s+Latency:\s+([\d\.]+)", line)
        if match:
            counter = match.group(1).strip()
            threads = match.group(2).strip()
            key = f"{counter} | {threads}"
            
            out_thr = float(match.group(3))
            out_lat = float(match.group(4))
            
            results[key]["throughput"].append(out_thr)
            results[key]["latency"].append(out_lat)

print("\n\n========================= RIGOROUS AVERAGE RESULTS =========================")
print(f"{'Counter Type':<18} | {'Threads':<10} | {'Avg Throughput (ops/s)':<22} | {'Avg Latency (ns/op)':<20}")
print("-" * 80)

for key, metrics in results.items():
    counter, threads = key.split(" | ")
    avg_thr = sum(metrics["throughput"]) / len(metrics["throughput"])
    avg_lat = sum(metrics["latency"]) / len(metrics["latency"])
    print(f"{counter:<18} | {threads:<10} | {avg_thr:<22.0f} | {avg_lat:<20.2f}")
