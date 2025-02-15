TODO:

- [x] - Save nodesets to file
- [ ] - Editable nodes
- [x] - Fix tile saving check for intersection
- [ ] - Animations??
- [ ] - ????
- [ ] - Extracting chunks
- [ ] - Layers
- [ ] - Auto-create nodeset
- [ ] - Allow dropping spritesheets
- [ ] - Tabs for Tiles, Entities

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
