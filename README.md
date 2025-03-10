In progress:
- [ ] - Show icon for editing layer name
- [ ] - Add input for editing layer name
- [ ] - Add icon for removing layer
- [ ] - Add icon for showing layer

ROADMAP:

- [x] - Save nodesets to file
- [ ] - Editable nodes
- [x] - Fix tile saving check for intersection
- [ ] - Extracting chunks
- [ ] - Layers
- [ ] - Allow dropping spritesheets
- [ ] - Tabs for Tiles, Entities
- [ ] - Fix dragging tiles that are bigger than 16x16 deleting itself
- [ ] - Support drag and drop files via `file_drop` event
- [ ] - Edit nodeset names

JSON Schema:

```typescript
{
    "nodes": {
        [node_name]: Node
    },
    // Chunks are re-usable pieces consisting of layers and nodes.
    "chunks": {
        // A chunk needs to be treat as a single "layer"
        [chunk_name]: File // Put in a file so we can lazy load it.
    },
    "maps": {
        [map_name]: File // Put in a file so we can lazy load it.
    }
}

Node = {
    x: number,
    y: number,
    w: number,
    h: number,
    path: string
}

Layer = {
    name: string
    nodes: (Tile | Entity)[]
    visible: boolean
}

Chunk = {
    name: string
    layers: Layer[]
}

Map = {
    name: string,
    w: number,
    h: number,
    layers: (Layer | Chunk)[]
}
```
