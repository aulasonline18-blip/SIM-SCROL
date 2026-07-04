# SIM Image Visual Taxonomy

This taxonomy defines when the SIM App should try a free software visual before
offering paid AI image generation.

## Core Rule

The app should draw by software when the visual can be honest, schematic,
lightweight, and useful for learning. It should not draw by software when the
student needs realism, anatomy detail, a real-world scene, a physical map, a
historical scene, or a photographic reference.

## Pedagogical Roles

| Role | Use when | Software-first examples |
|---|---|---|
| `concept_anchor` | A visual anchors an abstract idea. | concept map, simple diagram |
| `step_visualizer` | The student needs order or procedure. | flowchart, algorithm, process steps |
| `error_repair` | The visual corrects a common misconception. | contrast diagram, marked graph |
| `comparison` | The student must compare two ideas. | two-column comparison, Venn-style split |
| `timeline` | Events or stages must be ordered in time. | historical timeline, process chronology |
| `cycle` | The concept repeats. | water cycle, carbon cycle, life cycle |
| `structure_map` | Parts of a system must be organized. | table, concept map, grammar table |
| `graph_reasoning` | The student must read or reason from a graph. | line, parabola, axes, chart |
| `spatial_reasoning` | Space, shape, angle, or geometry matters. | unit circle, triangle, coordinate plane |
| `memory_hook` | A lightweight visual helps recall. | small mnemonic diagram |
| `realistic_reference` | A schematic is not enough. | photo/anatomy/scene, paid AI offer |

## Software-First Types

| Type | Renderer priority | Paid AI allowed without accept? |
|---|---|---|
| Cartesian graph | math template or graph renderer | No |
| Linear function | `linear_function` template | No |
| Quadratic/parabola | `quadratic_function` template | No |
| Unit circle | `unit_circle` template | No |
| Timeline | `TimelineRenderer` | No |
| Flowchart/process | `FlowchartRenderer` | No |
| Comparison | `ComparisonRenderer` | No |
| Cycle | `CycleRenderer` | No |
| Table | `TableRenderer` | No |
| Concept map | `ConceptMapRenderer` | No |
| Force/free-body diagram | `ForceDiagramRenderer` | No |
| Simple electrical circuit | `CircuitRenderer` | No |
| Syntax tree | `SyntaxTreeRenderer` | No |
| Food chain | `FoodChainRenderer` | No |

## Paid-AI Types

| Type | Reason |
|---|---|
| Realistic anatomy | SVG would be misleading or too poor pedagogically. |
| Human organ photo/reference | Needs visual realism. |
| Historical scene | Schematic may create false detail. |
| Physical map/landscape | Needs real geography or image detail. |
| Photorealistic animal/plant/ecosystem | Requires realism. |
| Portrait/human face | Requires paid image safeguards. |

## N2 Rules Added In This Sprint

- `VisualN2Result` now carries `confidence` and `pedagogicalRole`.
- Simple keyword hints must match as full words, so `organize` no longer
  matches `organ`.
- Explicit negation such as `sem foto realista` removes photo-realism hits and
  keeps the case eligible for software rendering.
- Mixed SVG/photo cases stay conservative: if N2 sees both SVG and AI realism
  signals, local software does not override the paid path.

## Current Free Render Catalog

| Renderer | Role | Scope |
|---|---|---|
| `QuadraticRenderer` | `graph_reasoning` | Parabola/quadratic graph |
| `LinearRenderer` | `graph_reasoning` | Linear function/line graph |
| `UnitCircleRenderer` | `spatial_reasoning` | Unit circle |
| `TimelineRenderer` | `timeline` | Ordered historical/process events |
| `FlowchartRenderer` | `step_visualizer` | Process, algorithm, steps |
| `ComparisonRenderer` | `comparison` | Two-side comparison |
| `CycleRenderer` | `cycle` | Water/carbon/life-style cycles |
| `TableRenderer` | `structure_map` | Tables and grammar/classification grids |
| `ForceDiagramRenderer` | `spatial_reasoning` | Free-body diagrams and force direction |
| `CircuitRenderer` | `structure_map` | Simple source/resistor/lamp circuit |
| `SyntaxTreeRenderer` | `structure_map` | Subject/predicate grammar structure |
| `FoodChainRenderer` | `step_visualizer` | Producer/consumer/decomposer energy flow |
| `ConceptMapRenderer` | `structure_map` | Concept maps and structural diagrams |

## N3 Pedagogical Contract

The Flutter client now sends `contractVersion=n3_pedagogical_v1` to
`/api/visual-route`.

The request keeps the legacy fields:

- `topic`
- `visualType`
- `imagePrompt`
- `hint`

It also sends richer pedagogical context when available:

- `n2.verdict`
- `n2.reason`
- `n2.matched`
- `n2.confidence`
- `n2.pedagogicalRole`
- `keyElements`
- `pedagogicalNeed`
- `highlightFocus`
- `complexity`
- `stableLang`

This keeps the current backend compatible while allowing a stronger N3 judge to
decide whether it can return a clean SVG, should return `no_image`, or should
let the normal paid offer path handle the visual.

## Acceptance Behavior

For software-first cases, the pipeline must return `source=local_software` or a
stronger free source (`svg_inline`, `math_template`, `n3_software`) and must not
call the paid image client.

For realistic or mixed-realism cases, the pipeline must preserve explicit paid
offer rules: no generation without `acceptedOfferId`, no paid image in
prefetch/background, and no local SVG that pretends to be a realistic reference.
