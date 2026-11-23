### Measured Benchmarks (Apple Silicon (arm64) · Version 26.7.2 (Build 25G332))

- **Live Keystroke Parser + Autocomplete:** **`0.128 ms`** avg across 500 8-stage parses (well inside 120 FPS `8.33 ms` budget)
- **End-to-End Media Pipelines Verified:** Apple `PDFKit` multi-page table merge (**PASS**) · Apple `Vision` OCR URL extractor (**PASS**)

#### 1. 5-Stage Typed Pipeline Throughput (`extract tables | filter | dedupe | sort | to markdown`)

| Input Volume | Total Pipeline Time | Throughput |
| ---: | ---: | ---: |
| 1000 rows | **16.03 ms** | **62387 rows/s** |
| 5000 rows | **69.51 ms** | **71935 rows/s** |
| 10000 rows | **110.29 ms** | **90670 rows/s** |
| 25000 rows | **309.82 ms** | **80693 rows/s** |

#### 2. End-to-End Cross-App Workflows

| Workflow | Pipeline Command | Measured Time | Manual Clicks |
| :--- | :--- | ---: | ---: |
| 500 Tabs Cleaner | `tabs | clean urls | dedupe | to markdown | copy` | **11.43 ms** | 34 → 1 |
| 10K Log Scrubber | `clip | filter ERROR | redact | summarize` | **18.56 ms** | 18 → 1 |
| PDFKit Table Merge | `selected pdfs | pdf text | tables | merge csv` | **5.21 ms** | 22 → 1 |
| 5K CSV → JSON | `clip | extract tables | to json | copy` | **68.68 ms** | 15 → 1 |
| Vision OCR → Links | `selected images | ocr | extract urls | md` | **1952.62 ms** | 14 → 1 |
