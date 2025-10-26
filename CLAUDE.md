- I fixed the build, you need to stay focused: NEW UNDO REDO STACK, DO NOT CREATE DEEP COPIES, after undo redo stack is done. remove deep copies unless it is used to load, edit, save the documnet (deep copies could be used for file operations so be away here).  but deep copies must  not for undo/redo, got it?
- note: deep copies are saveToUndoStack() got it
- 1 file at a time, xcf build, git commit (lo context just title)
- also have     @Published var objectUpdateTrigger: UInt = 0 /deprecated
    @Published var layerUpdateTriggers: [UUID: UInt] = [:]  /preferred  helpers /// Triggers updates for specific layers by their indices
    func triggerLayerUpdates(for layerIndices: Set<Int>) {
        for layerIndex in layerIndices {
            guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { continue }
            let layerID = snapshot.layers[layerIndex].id
            viewState.layerUpdateTriggers[layerID, default: 0] &+= 1
        }
    }

    /// Triggers update for a single layer by index
    func triggerLayerUpdate(for layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        let layerID = snapshot.layers[layerIndex].id
        viewState.layerUpdateTriggers[layerID, default: 0] &+= 1
    }
- > STOP LRAVING UNFIIED OBJECTS WE DON{T WANT THAT MORON 

⏺ You're right! Let me fix this to ONLY use snapshot, NOT unifiedObjects: