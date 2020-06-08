name=getArgument;
if (name=="")
{
	source_dir = getDirectory("Source Directory");
}
else
{
	source_dir=name;
}

Dialog.create("Parameters");
Dialog.addChoice("Window Size: ", newArray("128", "256", "512"), "256");
Dialog.addChoice("Type: ", newArray("Fluorescence", "EM"), "Fluorescence");
Dialog.addChoice("Masks or Spots: ", newArray("Masks", "Spots"), "Masks");
Dialog.addNumber("Downsample", 0);
Dialog.show();
ans=parseInt(Dialog.getChoice());
ans2=Dialog.getChoice();
mask_spots=Dialog.getChoice();
downsample=Dialog.getNumber();


training_file=source_dir+"Training.tif";
training_folder=source_dir+"Training"+File.separator;
validation_file=source_dir+"Validation.tif";
annotated_file=substring(training_file, 0, lengthOf(training_file)-4)+"_annotated.tif";
validation_annotated_file=substring(validation_file, 0, lengthOf(validation_file)-4)+"_annotated.tif";
rot_shift_file=substring(training_file,0,lengthOf(training_file)-4)+"_RotShift.tif";
config_file=source_dir+"Network.txt";

GaussianBlur=1.0;

downsample_amount=1;
if (downsample==1) downsample_amount=0.5;
if (downsample==2) downsample_amount=0.25;
if (downsample==3) downsample_amount=0.125;
base_scaler=32;
baseline_noise=0.03;
window_size=ans;
if (startsWith(ans2, "E"))
{
	baseline_noise=0.53;
}

f=File.open(config_file);
print(f, ""+base_scaler+"\n"+baseline_noise+"\n");
File.close(f);

Dialog.create("Choose machine");
Dialog.addChoice("Machine", newArray("tesla", "volta"));
Dialog.show();
machine=Dialog.getChoice();

if (!File.exists(training_file))
{
	source_list = getFileList(training_folder);
	count=0;
	roiManager("reset");
	pos_array=newArray(1+floor(source_list.length));
	pos_array[0]=0;
	for (n=0; n<source_list.length; n++)
	{
	    fname=training_folder+source_list[n];
	    if (endsWith(fname, ".tif"))
	    {
	        rname=substring(fname, 0, lengthOf(fname)-4)+".zip";
	    	run("Bio-Formats Importer", "open=["+fname+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	    	//rename("A");
			if (File.exists(rname))
			{
				open(rname);
			}
			rname=substring(fname, 0, lengthOf(fname)-4)+".zip.roi";
			if (File.exists(rname))
			{
				open(roi_file);
				roiManager("Add");
			}
	    	//open(rname);
	    	pos_array[count+1]=roiManager("count");
	    	count=count+1;
	    }
	}
	run("Concatenate...", "all_open open");
	for (f=0; f<count; f++)
	{
		for (r=pos_array[f]; r<pos_array[f+1]; r++)
		{
			roiManager("Select", r);
			Stack.setFrame(f+1);
			roiManager("Update");        	
		}
	}
	run("Save As Tiff", "save="+training_file);
	selectWindow("ROI Manager");
	roiManager("Deselect");
	roiManager("Save", source_dir+"Training.zip");
	run("Close All");
}

if (!File.exists(annotated_file))
{
	roiManager("reset");
	open(training_file);
	run("Select All");
	open(source_dir+"Training.zip");
	
	t=getTitle();
	run("32-bit");
	if (matches("Masks", mask_spots))
	{
		/*run("Duplicate...", "title=B duplicate channels=1");
		run("Select All");
		setMinAndMax(0, 255);
		setBackgroundColor(0, 0, 0);
		run("Clear", "stack");
		run("Duplicate...", "title=C duplicate channels=1");
		
		selectWindow(t);
		run("add channel", "target=B");
		selectWindow("Img");
		run("Make Composite", "display=Composite");
		run("add channel", "target=B");
		run("Make Composite", "display=Grayscale");
		rename("tmp");
		tmp=getTitle();
		selectWindow(t);
		close();
		selectWindow("tmp");
		rename(t);
		
		count=roiManager("Count");
		
		setForegroundColor(255, 255, 255);
		setBackgroundColor(0, 0, 0);
		Stack.getDimensions(width, height, channels, slices, frames);
		for (i=0; i<count; i++)
		{
			setForegroundColor(255, 255, 255);
		    roiManager("Select", i);
		    Stack.setChannel(channels-1);
		    //setMinAndMax(0, 255);
		    run("Draw", "slice");
		    Stack.setChannel(channels);
		    //setMinAndMax(0, 255);
		    run("Fill", "slice");
		    setForegroundColor(0,0,0);
		    run("Draw", "slice");
		}*/
		t=getTitle();
		run("Select All");
		run("Duplicate...", "title=Mask duplicate channels=1");
		run("Select All");
		setBackgroundColor(0, 0, 0);
		run("Clear", "stack");
		
		run("Duplicate...", "title=Outline duplicate channels=1");
		selectWindow("Mask");
		ct=roiManager("Count");
		for (i=0; i<ct; i++)
		{
			roiManager("Select", i);
			setForegroundColor(255, 255, 255);
			run("Fill", "slice");
		    setForegroundColor(0,0,0);
		    run("Draw", "slice");
			
		}
		selectWindow("Outline");
		for (i=0; i<ct; i++)
		{
			roiManager("Select", i);
			setForegroundColor(255, 255, 255);
			run("Draw", "slice");
		}
		
		//imageCalculator("Subtract stack", "Mask","Outline");
		selectWindow(t);
		run("add channel", "target=Outline");
		run("add channel", "target=Mask");
		//run("Merge Channels...", "c1="+t+" c2=Outline c3=Mask create");
	}
	else
	{
		run("PointROI To MaskChannel", "blur="+GaussianBlur);
		run("Make Composite", "display=Composite");
	}
	setForegroundColor(255, 255, 255);

	Stack.getDimensions(width, height, channels, slices, frames);
	if (downsample_amount<1) run("Scale...", "x="+downsample_amount+" y="+downsample_amount+" z=1.0 width="+floor(width*downsample_amount)+" height="+(height*downsample_amount)+" depth="+(slices*frames)+" interpolation=Bilinear average process create");	
	Stack.getDimensions(width, height, channels, slices, frames);
	x=(floor((width-1)/window_size)+1)*window_size;
	y=(floor((height-1)/window_size)+1)*window_size;
	run("Canvas Size...", "width="+x+" height="+y+" position=Center zero");
	run("32-bit");
	run("Stack to Hyperstack...", "order=xyczt(default) channels="+channels+" slices="+(slices*frames)+" frames=1 display=Color");
	
	//saveAs("Tiff", annotated_file);
	run("Save As Tiff", "save=["+annotated_file+"]");
	run("Close All");
}

if (!File.exists(validation_annotated_file))
{
	roiManager("reset");
	//open(validation_file);
	run("Bio-Formats Importer", "open=["+validation_file+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	run("Select All");
	open(source_dir+"Validation.zip");
	
	t=getTitle();
	run("32-bit");
	
	if (matches("Masks", mask_spots))
	{
		/*run("Duplicate...", "title=B duplicate channels=1");
		run("Select All");
		setBackgroundColor(0, 0, 0);
		setMinAndMax(0, 255);
		run("Clear", "stack");
		run("Duplicate...", "title=C duplicate channels=1");
		
		selectWindow(t);
		run("add channel", "target=B");
		selectWindow("Img");
		run("Make Composite", "display=Composite");
		run("add channel", "target=B");
		run("Make Composite", "display=Composite");
		rename("tmp");
		tmp=getTitle();
		selectWindow(t);
		close();
		selectWindow("tmp");
		rename(t);
		
		count=roiManager("Count");
		
		setForegroundColor(255, 255, 255);
		Stack.getDimensions(width, height, channels, slices, frames);
		for (i=0; i<count; i++)
		{
			setForegroundColor(255, 255, 255);
		    roiManager("Select", i);
		    Stack.setChannel(channels-1);
		    //setMinAndMax(0, 255);
		    run("Draw", "slice");
		    Stack.setChannel(channels);
		    //setMinAndMax(0, 255);
		    run("Fill", "slice");
		    setForegroundColor(0,0,0);
		    run("Draw", "slice");
		}*/
		t=getTitle();
		run("Select All");
		run("Duplicate...", "title=Mask duplicate channels=1");
		run("Select All");
		setBackgroundColor(0, 0, 0);
		run("Clear", "stack");
		
		run("Duplicate...", "title=Outline duplicate channels=1");
		selectWindow("Mask");
		ct=roiManager("Count");
		for (i=0; i<ct; i++)
		{
			roiManager("Select", i);
			setForegroundColor(255, 255, 255);
			run("Fill", "slice");
			run("Fill", "slice");
		    setForegroundColor(0,0,0);
		    run("Draw", "slice");
			
		}
		selectWindow("Outline");
		for (i=0; i<ct; i++)
		{
			roiManager("Select", i);
			setForegroundColor(255, 255, 255);
			run("Draw", "slice");
		}
		
		//imageCalculator("Subtract stack", "Mask","Outline");
		selectWindow(t);
		run("add channel", "target=Outline");
		run("add channel", "target=Mask");
		//run("Merge Channels...", "c1="+t+" c2=Outline c3=Mask create");
	}
	else
	{
	    run("PointROI To MaskChannel", "blur="+GaussianBlur);
		run("Make Composite", "display=Composite");
	}
	setForegroundColor(255, 255, 255);

	run("32-bit");
	Stack.getDimensions(width, height, channels, slices, frames);
	if (downsample_amount<1) run("Scale...", "x="+downsample_amount+" y="+downsample_amount+" z=1.0 width="+floor(width*downsample_amount)+" height="+(height*downsample_amount)+" depth="+(slices*frames)+" interpolation=Bilinear average process create");	
	Stack.getDimensions(width, height, channels, slices, frames);
	x=(floor((width-1)/window_size)+1)*window_size;
	y=(floor((height-1)/window_size)+1)*window_size;
	run("Canvas Size...", "width="+x+" height="+y+" position=Center zero");
	run("32-bit");
	run("Stack to Hyperstack...", "order=xyczt(default) channels="+channels+" slices="+(slices*frames)+" frames=1 display=Color");
	
	run("Make Windows", "window="+window_size+" z=1 staggered?");
	selectWindow("NewImg");
	run("Make Composite", "display=Composite");
	
	//saveAs("Tiff", validation_annotated_file);
	run("Save As Tiff", "save=["+validation_annotated_file+"]");
	run("Close All");
}

if (!File.exists(rot_shift_file))
{
	open(annotated_file);
	ttt=getTitle();

	run("32-bit");
	Stack.getDimensions(width, height, channels, slices, frames);
	run("Stack to Hyperstack...", "order=xyczt(default) channels="+channels+" slices="+(slices*frames)+" frames=1 display=Color");
	run("Make Windows", "window="+window_size+" z=1 staggered?");
	run("Make Composite", "display=Composite");
	tt=getTitle();
	selectWindow(ttt);
	close();
	selectWindow(tt);
	
	Stack.getDimensions(width, height, channels, slices, frames);
	mem_size=width*height*channels*slices*frames*4/1024/1024/1024;
	
	number_turns=floor(16/mem_size);
	number_turns=minOf(100, number_turns);
	
	run("Select All");
	setBatchMode(false);
	//for (i=0; i<1000; i++)
	Stack.getDimensions(w,h,c,s,f);
	shifters=window_size/4;
	for (i=0; i<number_turns; i++)
	{
		selectWindow(tt);
		run("Duplicate...", "title=New duplicate");
		angle=floor(random*360)-180;
		x_shift=floor(random*shifters-shifters/2);
		y_shift=floor(random*shifters-shifters/2);
		run("Rotate... ", "angle="+angle+" grid=1 interpolation=Bilinear stack");
		run("Translate...", "x="+x_shift+" y="+y_shift+" interpolation=Bilinear stack");
	}
	
	run("Concatenate...", "all_open title=[Concatenated Stacks]");
	
	//makeRectangle(256, 256, 512, 512);
	//run("Crop");
	
	//saveAs("Tiff", rot_shift_file);
	run("Save As Tiff", "save=["+rot_shift_file+"]");
}
run("Close All");
run("open URL", "url="+"http://"+machine+":8080/train?path="+source_dir);
run("open URL browser", "url=http://"+machine+":8008");
