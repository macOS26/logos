# inkpen-memory-leak-investigation

- [⏳] 1. Step 1: Examine InkpenDocument.swift — document lifecycle, tab close, cleanup
- [ ] 2. Step 2: Examine DocumentBasedContentView.swift and DocumentBasedMainView.swift — tab management, view lifecycle
- [ ] 3. Step 3: Examine DocumentState.swift and DocumentStateRegistry.swift — shared state between tabs
- [ ] 4. Step 4: Examine DrawingCanvasRegistry.swift — canvas/image caching
- [ ] 5. Step 5: Examine AppState.swift — global shared state, image caches
- [ ] 6. Step 6: Examine Image handling — NSImage caching, bitmap contexts, rasterized layers
- [ ] 7. Step 7: Search for strong reference cycles (closures, delegates)
- [ ] 8. Step 8: Compile findings and fix leaks

---
*Status: 0 done, 1 in progress, 0 failed, 7 pending*
