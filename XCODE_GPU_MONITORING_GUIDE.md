# 🎯 Xcode GPU Monitoring Guide

## **Problem**: GPU usage not showing in Xcode Instruments

### **Solution**: Use the correct Instruments template

## **Step 1: Open Xcode Instruments**
1. In Xcode, go to **Product** → **Profile** (⌘+I)
2. Or use **Product** → **Instruments** (⌘+I)

## **Step 2: Select GPU Monitoring Template**
Instead of "Activity Monitor", choose one of these templates:

### **Option A: Metal System Trace (Recommended)**
- Shows detailed Metal GPU usage
- Displays GPU utilization percentage
- Shows GPU memory usage
- Provides frame-by-frame analysis

### **Option B: GPU Counters**
- Shows GPU performance counters
- Displays GPU utilization metrics
- Shows shader performance

### **Option C: Core Animation**
- Shows GPU rendering performance
- Displays frame rates
- Shows rendering pipeline metrics

## **Step 3: Configure GPU Monitoring**

### **For Metal System Trace:**
1. Select "Metal System Trace" template
2. Click "Choose"
3. In the Instruments window:
   - Look for "GPU Utilization" section
   - Check "GPU %" metric
   - Look for "GPU Memory" section

### **For GPU Counters:**
1. Select "GPU Counters" template
2. Click "Choose"
3. In the Instruments window:
   - Add "GPU Utilization" instrument
   - Add "GPU Memory" instrument
   - Add "GPU Time" instrument

## **Step 4: Run Your App**
1. Click the red record button
2. Your app will launch automatically
3. Perform actions in your app
4. Watch GPU metrics in real-time

## **Expected GPU Metrics:**
- **GPU Utilization**: 0-100% (should be 0% when idle)
- **GPU Memory**: Current GPU memory usage
- **GPU Time**: Time spent on GPU operations
- **Render Passes**: Number of render passes per frame

## **Troubleshooting:**
- If GPU metrics are still 0%, ensure your app is actually using Metal
- Check that MetalComputeEngine is initialized
- Verify that GPU-accelerated functions are being called

## **Alternative: Activity Monitor + GPU**
You can also add GPU monitoring to the Activity Monitor:
1. Open Activity Monitor template
2. Click the "+" button to add instruments
3. Search for "GPU" and add GPU-related instruments
4. This will show both CPU and GPU metrics together
