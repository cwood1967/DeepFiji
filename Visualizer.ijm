thresh=0.2;

t=getTitle();
Stack.getDimensions(width, height, channels, slices, frames);
run("Duplicate...", "title=Mask duplicate channels="+channels);
selectWindow(t);
//run("Threshold...");
run("Duplicate...", "title=Outline duplicate channels="+(channels-1));
imageCalculator("Subtract create stack", "Mask","Outline");
setThreshold(thresh, 1000000000000000000000000000000.0000);
setOption("BlackBackground", true);
run("Convert to Mask", "method=Default background=Dark black");
roiManager("reset");
run("Analyze Particles...", "add stack");
selectWindow(t);
run("Duplicate...", "duplicate channels=1");
roiManager("show all");
//Stack.setActiveChannels("10000");
run("Grays");
