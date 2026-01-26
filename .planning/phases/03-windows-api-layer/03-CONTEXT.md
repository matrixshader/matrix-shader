# Phase 3: Windows API Layer - Context

**Gathered:** 2026-01-26
**Status:** Ready for planning

<domain>
## Phase Boundary

P/Invoke declarations and Windows API wrappers for window enumeration, monitor detection, and window positioning. This is infrastructure that Phase 4 (Window Identity) and Phase 5 (Layout Service) build upon.

**Success Criteria:**
1. Application can enumerate all visible windows with correct handles
2. Application can detect all connected monitors with correct bounds
3. Application can reposition windows to exact pixel coordinates

</domain>

<decisions>
## Implementation Decisions

### Window Filtering
- Include minimized windows in enumeration (track all Matrix windows)
- Enumerate all windows, let Identity Service (Phase 4) filter — matches PowerShell's 4-layer approach
- API choice and return type: Claude's discretion based on AOT compatibility

### Monitor Handling
- Match PowerShell behavior for DPI handling, virtual desktop support, monitor info fields, and change detection
- If PowerShell approach is unclear or doesn't apply cleanly: Claude decides
- Key insight: This layer provides raw data; Layout Service interprets it

### Border Compensation
- **Pixel-perfect positioning required** — compensate for Windows invisible borders
- Detect Windows version (10 vs 11) for version-specific border offsets if needed
- Priority on rounding: maintain configured gap size exactly, adjust window size if needed
- Preserve z-order when repositioning (don't bring to top)

### Claude's Discretion
- Which Windows APIs to use (can use modern equivalents if cleaner)
- WindowInfo struct design (what fields to include)
- Internal implementation details for P/Invoke marshalling
- How to handle edge cases not covered by PowerShell

</decisions>

<specifics>
## Specific Ideas

- "The C# version must work exactly like the PowerShell version does today" — core project value
- PowerShell WindowLayoutEngine.ps1 is reference implementation
- 4-layer identity resolution exists in Phase 4, not this phase — keep separation clean

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-windows-api-layer*
*Context gathered: 2026-01-26*
