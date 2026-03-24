---
name: excalidraw-obsidian
description: "Use when the user asks to generate diagrams, mind maps, flowcharts, or architecture visualizations and save them to Obsidian. Creates .excalidraw.md files compatible with the Obsidian Excalidraw plugin."
---

# Excalidraw Diagram Generator for Obsidian

## Overview

Gera diagramas Excalidraw e salva como `.excalidraw.md` no vault Obsidian (`~/Obsidian-Mind/`).
O plugin Obsidian Excalidraw aceita JSON puro (nao precisa comprimir).

## When to Use

- Usuario pede mapa mental, diagrama, fluxograma, arquitetura
- Fase 2 do KnowledgeForge: visualizar knowledge map como diagrama
- Qualquer visualizacao estruturada de conceitos e relacoes

## Output Directory

Salvar em: `~/Obsidian-Mind/Attachments/excalidraw/`
Ou no diretorio que o usuario especificar dentro do vault.

## File Format (.excalidraw.md)

```markdown
---

excalidraw-plugin: parsed
tags: [excalidraw]

---
==Warning: Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document.==


# Excalidraw Data

## Text Elements
Label1 ^id1

Label2 ^id2

%%
## Drawing
```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "openclaw-knowledgeforge",
  "elements": [ ... ],
  "appState": {
    "gridSize": null,
    "viewBackgroundColor": "#ffffff"
  },
  "files": {}
}
`` `
%%
```

(Note: the closing backticks above have a space to avoid breaking this SKILL.md — in real output use three backticks without spaces)

## Element Types

### Rectangle (box/node)
```json
{
  "id": "unique-id",
  "type": "rectangle",
  "x": 100,
  "y": 100,
  "width": 200,
  "height": 60,
  "strokeColor": "#1e1e1e",
  "backgroundColor": "#a5d8ff",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "roundness": { "type": 3 },
  "text": "",
  "fontSize": 16,
  "fontFamily": 1,
  "opacity": 100,
  "angle": 0,
  "seed": 1,
  "version": 1,
  "groupIds": [],
  "boundElements": [
    { "type": "text", "id": "text-id" },
    { "type": "arrow", "id": "arrow-id" }
  ]
}
```

### Text (label inside a shape)
```json
{
  "id": "text-id",
  "type": "text",
  "x": 110,
  "y": 115,
  "width": 180,
  "height": 30,
  "text": "Label Here",
  "fontSize": 16,
  "fontFamily": 1,
  "textAlign": "center",
  "verticalAlign": "middle",
  "strokeColor": "#1e1e1e",
  "containerId": "parent-rectangle-id",
  "opacity": 100,
  "angle": 0,
  "seed": 2,
  "version": 1,
  "groupIds": []
}
```

### Arrow (connection between nodes)
```json
{
  "id": "arrow-id",
  "type": "arrow",
  "x": 300,
  "y": 130,
  "width": 100,
  "height": 0,
  "points": [[0, 0], [100, 0]],
  "strokeColor": "#1e1e1e",
  "strokeWidth": 2,
  "startBinding": { "elementId": "source-id", "focus": 0, "gap": 1 },
  "endBinding": { "elementId": "target-id", "focus": 0, "gap": 1 },
  "opacity": 100,
  "angle": 0,
  "seed": 3,
  "version": 1,
  "groupIds": [],
  "endArrowhead": "arrow",
  "startArrowhead": null
}
```

### Ellipse (for mind map central node)
```json
{
  "id": "ellipse-id",
  "type": "ellipse",
  "x": 300,
  "y": 200,
  "width": 180,
  "height": 80,
  "strokeColor": "#1e1e1e",
  "backgroundColor": "#b2f2bb",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "opacity": 100,
  "angle": 0,
  "seed": 4,
  "version": 1,
  "groupIds": [],
  "boundElements": [
    { "type": "text", "id": "text-id" }
  ]
}
```

## Color Palette (Excalidraw defaults)

| Use | Color | Hex |
|-----|-------|-----|
| Blue (primary) | Light blue fill | #a5d8ff |
| Green (success) | Light green fill | #b2f2bb |
| Yellow (warning) | Light yellow fill | #ffec99 |
| Red (danger) | Light red fill | #ffc9c9 |
| Purple (special) | Light purple fill | #d0bfff |
| Orange (accent) | Light orange fill | #ffd8a8 |
| Gray (neutral) | Light gray fill | #e9ecef |
| Stroke (default) | Dark | #1e1e1e |
| Background | White | #ffffff |

## Layout Strategies

### Mind Map
- Central node: ellipse at (400, 300), larger size
- Branches: rectangles radiating outward in a star pattern
- Sub-branches: smaller rectangles further out
- Arrows from center to branches, branches to sub-branches
- Use colors to distinguish categories

### Flowchart (top-to-bottom)
- Start at y=50, increment y by 120 for each step
- Center horizontally at x=400
- Decision points: use diamond (rotated rectangle) or different color
- Arrows flowing downward between steps

### Architecture Diagram (left-to-right)
- Layers from left (x=50) to right (x increments by 300)
- Group related components vertically
- Arrows showing data flow left-to-right
- Color-code by layer/domain

### Comparison/Grid
- Columns at x=100, x=400, x=700
- Rows at y=100, y=220, y=340
- Headers in darker color
- Items in lighter fills

## Generation Process

1. Identify diagram type (mind map, flowchart, architecture, comparison)
2. List all nodes and their relationships
3. Choose layout strategy
4. Assign positions (x, y) using the layout grid
5. Create elements array (rectangles + texts + arrows)
6. Generate the `## Text Elements` section from all text nodes
7. Wrap in `.excalidraw.md` format
8. Write to Obsidian vault using exec tool

## Important Rules

- Every text inside a shape needs TWO elements: the shape + a text element with `containerId` pointing to the shape
- The shape needs `boundElements` listing the text element
- Arrows need `startBinding` and `endBinding` referencing the connected shapes
- Connected shapes need `boundElements` listing the arrows
- Each `id` must be unique (use descriptive slugs like `node-api`, `arrow-api-to-db`)
- `## Text Elements` section must list all text content with `^id` format
- Keep IDs short (8-12 chars), alphanumeric
- Always set `"type": "excalidraw"` and `"version": 2` in the wrapper
- JSON must be valid (no trailing commas, no comments)

## Example: Simple 3-Node Flow

File: `~/Obsidian-Mind/Attachments/excalidraw/example-flow.excalidraw.md`

```
---

excalidraw-plugin: parsed
tags: [excalidraw]

---
==Warning: Switch to EXCALIDRAW VIEW==

# Excalidraw Data

## Text Elements
Input ^txt1

Process ^txt2

Output ^txt3

%%
## Drawing
```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "openclaw-knowledgeforge",
  "elements": [
    {"id":"box1","type":"rectangle","x":100,"y":100,"width":160,"height":60,"strokeColor":"#1e1e1e","backgroundColor":"#a5d8ff","fillStyle":"solid","strokeWidth":2,"roundness":{"type":3},"opacity":100,"angle":0,"seed":1,"version":1,"groupIds":[],"boundElements":[{"type":"text","id":"txt1"},{"type":"arrow","id":"arr1"}]},
    {"id":"txt1","type":"text","x":130,"y":115,"width":100,"height":30,"text":"Input","fontSize":16,"fontFamily":1,"textAlign":"center","verticalAlign":"middle","strokeColor":"#1e1e1e","containerId":"box1","opacity":100,"angle":0,"seed":2,"version":1,"groupIds":[]},
    {"id":"box2","type":"rectangle","x":380,"y":100,"width":160,"height":60,"strokeColor":"#1e1e1e","backgroundColor":"#b2f2bb","fillStyle":"solid","strokeWidth":2,"roundness":{"type":3},"opacity":100,"angle":0,"seed":3,"version":1,"groupIds":[],"boundElements":[{"type":"text","id":"txt2"},{"type":"arrow","id":"arr1"},{"type":"arrow","id":"arr2"}]},
    {"id":"txt2","type":"text","x":410,"y":115,"width":100,"height":30,"text":"Process","fontSize":16,"fontFamily":1,"textAlign":"center","verticalAlign":"middle","strokeColor":"#1e1e1e","containerId":"box2","opacity":100,"angle":0,"seed":4,"version":1,"groupIds":[]},
    {"id":"box3","type":"rectangle","x":660,"y":100,"width":160,"height":60,"strokeColor":"#1e1e1e","backgroundColor":"#ffec99","fillStyle":"solid","strokeWidth":2,"roundness":{"type":3},"opacity":100,"angle":0,"seed":5,"version":1,"groupIds":[],"boundElements":[{"type":"text","id":"txt3"},{"type":"arrow","id":"arr2"}]},
    {"id":"txt3","type":"text","x":690,"y":115,"width":100,"height":30,"text":"Output","fontSize":16,"fontFamily":1,"textAlign":"center","verticalAlign":"middle","strokeColor":"#1e1e1e","containerId":"box3","opacity":100,"angle":0,"seed":6,"version":1,"groupIds":[]},
    {"id":"arr1","type":"arrow","x":260,"y":130,"width":120,"height":0,"points":[[0,0],[120,0]],"strokeColor":"#1e1e1e","strokeWidth":2,"startBinding":{"elementId":"box1","focus":0,"gap":1},"endBinding":{"elementId":"box2","focus":0,"gap":1},"opacity":100,"angle":0,"seed":7,"version":1,"groupIds":[],"endArrowhead":"arrow","startArrowhead":null},
    {"id":"arr2","type":"arrow","x":540,"y":130,"width":120,"height":0,"points":[[0,0],[120,0]],"strokeColor":"#1e1e1e","strokeWidth":2,"startBinding":{"elementId":"box2","focus":0,"gap":1},"endBinding":{"elementId":"box3","focus":0,"gap":1},"opacity":100,"angle":0,"seed":8,"version":1,"groupIds":[],"endArrowhead":"arrow","startArrowhead":null}
  ],
  "appState": {"gridSize":null,"viewBackgroundColor":"#ffffff"},
  "files": {}
}
`` `
%%
```
