#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_PATH="${1:-$ROOT_DIR/.tools/android-stability-current/android-stability-report.json}"
MIN_SAMPLES="${PSW_ANDROID_RUNTIME_MIN_SAMPLES:-12}"
MIN_OBSERVED_RATIO="${PSW_ANDROID_RUNTIME_MIN_OBSERVED_RATIO:-0.65}"
MAX_AVG_CPU_PCT="${PSW_ANDROID_RUNTIME_MAX_AVG_CPU_PCT:-30}"
MAX_CPU_PCT="${PSW_ANDROID_RUNTIME_MAX_CPU_PCT:-40}"
MAX_AVG_PSS_MB="${PSW_ANDROID_RUNTIME_MAX_AVG_PSS_MB:-380}"
MAX_PSS_MB="${PSW_ANDROID_RUNTIME_MAX_PSS_MB:-430}"
MAX_PSS_GROWTH_MB="${PSW_ANDROID_RUNTIME_MAX_PSS_GROWTH_MB:-80}"
MAX_SWAP_PSS_MB="${PSW_ANDROID_RUNTIME_MAX_SWAP_PSS_MB:-32}"

if [[ "$REPORT_PATH" != /* ]]; then
	REPORT_PATH="$ROOT_DIR/$REPORT_PATH"
fi

if [[ ! -f "$REPORT_PATH" ]]; then
	printf 'Android runtime report is missing: %s\n' "$REPORT_PATH" >&2
	exit 1
fi

node - "$REPORT_PATH" "$MIN_SAMPLES" "$MIN_OBSERVED_RATIO" "$MAX_AVG_CPU_PCT" "$MAX_CPU_PCT" "$MAX_AVG_PSS_MB" "$MAX_PSS_MB" "$MAX_PSS_GROWTH_MB" "$MAX_SWAP_PSS_MB" <<'NODE'
const fs = require("fs");
const [
  reportPath,
  minSamplesRaw,
  minObservedRatioRaw,
  maxAvgCpuRaw,
  maxCpuRaw,
  maxAvgPssRaw,
  maxPssRaw,
  maxPssGrowthRaw,
  maxSwapPssRaw,
] = process.argv.slice(2);
const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const metrics = report.metrics || {};
const number = (value, fallback = 0) => Number.isFinite(Number(value)) ? Number(value) : fallback;
const limits = {
  minSamples: number(minSamplesRaw),
  minObservedRatio: number(minObservedRatioRaw),
  maxAvgCpu: number(maxAvgCpuRaw),
  maxCpu: number(maxCpuRaw),
  maxAvgPss: number(maxAvgPssRaw),
  maxPss: number(maxPssRaw),
  maxPssGrowth: number(maxPssGrowthRaw),
  maxSwapPss: number(maxSwapPssRaw),
};
const values = {
  samples: number(report.sample_count),
  observed: number(report.observed_duration_seconds),
  wall: number(report.wall_duration_seconds),
  target: number(report.target_duration_seconds),
  avgCpu: number(metrics.avg_cpu_pct),
  maxCpu: number(metrics.max_cpu_pct),
  avgPss: number(metrics.avg_pss_mb),
  maxPss: number(metrics.max_pss_mb),
  pssGrowth: number(metrics.pss_growth_mb),
  maxSwapPss: number(metrics.max_swap_pss_mb),
};
const failures = [];
const effectiveObserved = Math.max(values.observed, values.wall);
const observedRatio = values.target > 0 ? effectiveObserved / values.target : 1;
if (values.samples < limits.minSamples) failures.push(`sample_count ${values.samples} < ${limits.minSamples}`);
if (observedRatio < limits.minObservedRatio) failures.push(`observed_ratio ${observedRatio.toFixed(2)} < ${limits.minObservedRatio}`);
if (values.avgCpu > limits.maxAvgCpu) failures.push(`avg_cpu_pct ${values.avgCpu} > ${limits.maxAvgCpu}`);
if (values.maxCpu > limits.maxCpu) failures.push(`max_cpu_pct ${values.maxCpu} > ${limits.maxCpu}`);
if (values.avgPss > limits.maxAvgPss) failures.push(`avg_pss_mb ${values.avgPss} > ${limits.maxAvgPss}`);
if (values.maxPss > limits.maxPss) failures.push(`max_pss_mb ${values.maxPss} > ${limits.maxPss}`);
if (values.pssGrowth > limits.maxPssGrowth) failures.push(`pss_growth_mb ${values.pssGrowth} > ${limits.maxPssGrowth}`);
if (values.maxSwapPss > limits.maxSwapPss) failures.push(`max_swap_pss_mb ${values.maxSwapPss} > ${limits.maxSwapPss}`);
if (failures.length) {
  console.error(`Android runtime budget failed: ${reportPath}`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}
const wallLabel = values.wall > 0 ? `${values.wall}s` : "n/a";
console.log([
  `Android runtime budget passed: ${reportPath}`,
  `samples ${values.samples}, observed ${values.observed}s/${values.target}s, wall ${wallLabel}`,
  `CPU avg/max ${values.avgCpu}%/${values.maxCpu}% <= ${limits.maxAvgCpu}%/${limits.maxCpu}%`,
  `PSS avg/max/growth ${values.avgPss}MB/${values.maxPss}MB/${values.pssGrowth}MB <= ${limits.maxAvgPss}MB/${limits.maxPss}MB/${limits.maxPssGrowth}MB`,
  `Swap PSS max ${values.maxSwapPss}MB <= ${limits.maxSwapPss}MB`,
].join("\n"));
NODE
