#!/bin/bash
# ImageAnalyzer latency benchmark
# Run: ./Benchmarks/image-analyzer-benchmark.sh
# Requires: AirplaneAI built, 1920x1080 test image
echo "ImageAnalyzer latency benchmark"
echo "This benchmark requires running within the app context."
echo "Use the app's debug build with AIRPLANE_DEBUG to measure:"
echo "  - Cold analysis: first image after app launch"
echo "  - Warm analysis: subsequent images"
echo "Target: Cold < 3s, Warm < 1s on 24 GB Mac"
echo ""
echo "To record baselines, add results to Benchmarks/baselines/image-analyzer.json"
