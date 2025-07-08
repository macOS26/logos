# OBJECT REORDERING TEST PLAN
## Comprehensive Testing for Layer Object Management

### 🎯 MAIN ISSUE TEST: Moving 2nd Object Above 1st Object
**Objective**: Verify that the 2nd object in a layer can be moved to position 1 (above 1st object)

**Test Steps**:
1. Create a new layer with 2+ objects
2. Expand the layer to show object list
3. Drag the 2nd object (index 1) onto the 1st object (index 0)
4. **Expected Result**: 2nd object should move to position 1 (top of layer)
5. **UI Verification**: Object order in layer panel should update correctly

**Pass Criteria**: 
- ✅ Object successfully moves to top position
- ✅ Layer panel updates to show new order
- ✅ No console errors during operation

---

### 🔵 INSERTION ZONES TEST
**Objective**: Verify blue insertion indicators work correctly

**Test Steps**:
1. Start dragging any object within a layer
2. **Expected Results During Drag**:
   - Blue insertion zones appear between objects
   - Zones are 1px tall (professional appearance) 
   - Zones only visible during drag operations
   - Zones highlight when hovering over them

**Pass Criteria**:
- ✅ Insertion zones appear only during drag
- ✅ Blue highlighting when hovering
- ✅ Clean professional appearance (1px tall)
- ✅ Zones disappear when drag ends

---

### 🔄 CROSS-LAYER MOVEMENT TEST
**Objective**: Verify objects can move between different layers

**Test Steps**:
1. Create 2+ layers with objects in each
2. Drag object from Layer A to Layer B
3. **Expected Results**:
   - Object moves from source to target layer
   - Selection updates to target layer
   - Source layer object count decreases
   - Target layer object count increases

**Pass Criteria**:
- ✅ Object successfully transfers between layers
- ✅ Object counts update correctly
- ✅ Selection follows moved object

---

### 🔝 TOP POSITION TEST  
**Objective**: Verify objects can be moved to the very top of any layer

**Test Steps**:
1. Create layer with 3+ objects
2. Drag bottom object to top insertion zone
3. **Expected Results**:
   - Object moves to highest index (top position)
   - Other objects shift down accordingly
   - Visual order updates in layer panel

**Pass Criteria**:
- ✅ Object reaches position 1 (top of layer)
- ✅ Other objects reorder correctly
- ✅ No index out-of-bounds errors

---

### 🔒 LOCKED LAYER PROTECTION TEST
**Objective**: Verify lock protection prevents unauthorized moves

**Test Steps**:
1. Lock a layer containing objects
2. Try to drag objects from/to locked layer
3. **Expected Results**:
   - Console shows protection messages
   - No objects actually move
   - Drag operations are blocked
   - Lock indicators visible

**Console Messages Expected**:
- `🚫 Cannot move objects from locked layer '[LayerName]'`
- `🚫 Cannot move objects to locked layer '[LayerName]'`

**Pass Criteria**:
- ✅ All drag operations to/from locked layers blocked
- ✅ Clear console feedback provided
- ✅ No objects move when layer is locked

---

### 🎨 VISUAL FEEDBACK TEST
**Objective**: Verify all visual indicators work correctly

**Test Elements to Verify**:
- **Blue insertion zones**: 1px tall, appear during drag
- **Green layer highlighting**: When objects hover over layers
- **Object drag previews**: Show object name and icon
- **Drop indicators**: Change color based on validity (green/red)

**Pass Criteria**:
- ✅ All visual elements appear as expected
- ✅ Colors match design specifications
- ✅ Animations smooth and professional
- ✅ No visual glitches during drag operations

---

### 🧪 EDGE CASES TEST
**Additional scenarios to verify robustness**:

1. **Single Object Layer**: Moving only object in layer
2. **Empty Target Layer**: Moving object to layer with no objects  
3. **Maximum Objects**: Testing with many objects in single layer
4. **Rapid Dragging**: Quick drag operations in succession
5. **Canvas Layer Protection**: Ensure Canvas layer objects can't be reordered

---

### 📊 TEST EXECUTION CHECKLIST

**Pre-Test Setup**:
- [ ] App launches successfully  
- [ ] Layer panel is visible and expanded
- [ ] Multiple layers created with test objects
- [ ] Console window open for monitoring messages

**During Testing**:
- [ ] All drag operations feel smooth and responsive
- [ ] Visual feedback appears instantly
- [ ] No lag or UI freezing
- [ ] Console shows appropriate messages

**Post-Test Verification**:
- [ ] Object positions persist after drag completion
- [ ] Layer panel accurately reflects new order
- [ ] Selection states update correctly
- [ ] No memory leaks or performance degradation

---

### 🏆 SUCCESS CRITERIA
**All tests must pass for functionality to be considered working**:

1. ✅ **Core Issue Fixed**: 2nd object can move above 1st object
2. ✅ **Professional UI**: Clean visual feedback with proper indicators
3. ✅ **Lock Protection**: Comprehensive security for locked content
4. ✅ **Cross-Layer Support**: Objects move between layers seamlessly  
5. ✅ **Edge Cases Handled**: Robust behavior in all scenarios
6. ✅ **Performance**: Smooth, responsive drag operations

---

**🔥 CRITICAL TEST**: The main reported issue
> **"I can't move the 2nd object on a layer above the first object to make it to position 1"**

This specific scenario must work flawlessly to consider the fix successful! 