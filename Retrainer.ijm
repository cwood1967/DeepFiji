name=getArgument;
if (name=="")
{
	source_dir = getDirectory("Source Directory");
}
else
{
	source_dir=name;
}
setBatchMode(false);

training_file=source_dir+"Training.tif";
validation_file=source_dir+"Validation.tif";
annotated_file=substring(training_file, 0, lengthOf(training_file)-4)+"_annotated.tif";
validation_annotated_file=substring(validation_file, 0, lengthOf(validation_file)-4)+"_annotated.tif";
rot_shift_file=substring(training_file,0,lengthOf(training_file)-4)+"_RotShift.tif";
rot_shift_retrain_file=substring(training_file,0,lengthOf(training_file)-4)+"_retrain_RotShift.tif";
retrain_directory=source_dir+"Retrain"+File.separator;
retrain_file=substring(training_file, 0, lengthOf(training_file)-4)+"_retrain_annotated.tif";
retrain_tmp_directory=source_dir+"RetrainTmp"+File.separator;

File.makeDirectory(retrain_tmp_directory);

GaussianBlur=1.0;

config_file=source_dir+"Network.txt";
f=File.openAsString(config_file);
lines=split(f, "\n");
x_dim=parseInt(lines[2]);
model_no=IJ.log(lines[5]);
no_channels=parseInt(lines[6]);
window_size=x_dim;

Dialog.create("Choose machine");
Dialog.addChoice("Machine", newArray("tesla", "volta"));
Dialog.addChoice("Masks or Spots: ", newArray("Masks", "Spots"), "Masks");
Dialog.show();
machine=Dialog.getChoice();
mask_spots=Dialog.getChoice();

//*********************MAKE ANNOTATED FILES*********************************//
retrain_list = getFileList(retrain_directory);
number_of_files=0;
for (n=0; n<retrain_list.length; n++)
{
	cur_file=retrain_directory+retrain_list[n];
	if (endsWith(cur_file, ".tif"))
	{
		number_of_files=number_of_files+1;
		roiManager("reset");
		open(cur_file);
		roi_file=substring(cur_file, 0, lengthOf(cur_file)-4)+".zip";
		if (File.exists(roi_file))
		{
			open(roi_file);
		}
		roi_file=substring(cur_file, 0, lengthOf(cur_file)-4)+".zip.roi";
		if (File.exists(roi_file))
		{
			open(roi_file);
			roiManager("Add");
		}

		t=getTitle();
		run("32-bit");
		if (matches("Masks", mask_spots))
		{
			Stack.setChannel(no_channels+1);
			run("Select All");
			setBackgroundColor(0, 0, 0);
			run("Clear", "slice");
			Stack.setChannel(no_channels+2);
			run("Select All");
			setBackgroundColor(0, 0, 0);
			run("Clear", "slice");
			
			count=roiManager("Count");
			
			setForegroundColor(255, 255, 255);
			Stack.getDimensions(width, height, channels, slices, frames);
			for (i=0; i<count; i++)
			{
				setForegroundColor(255, 255, 255);
			    roiManager("Select", i);
			    Stack.setChannel(channels-1);
			    run("Draw", "slice");
			    Stack.setChannel(channels);
			    run("Fill", "slice");
			    setForegroundColor(0,0,0);
			    run("Draw", "slice");
			}
		}
		else
		{
			Stack.getDimensions(width, height, channels, slices, frames);
			Stack.setChannel(channels-1);
			run("Delete Slice", "delete=channel");
			Stack.setChannel(channels-1);
			run("Delete Slice", "delete=channel");
			run("PointROI To MaskChannel", "blur="+GaussianBlur);
			run("Make Composite", "display=Composite");
		}
		setForegroundColor(255, 255, 255);
	
		Stack.getDimensions(width, height, channels, slices, frames);
		x=(floor((width-1)/window_size)+1)*window_size;
		y=(floor((height-1)/window_size)+1)*window_size;
		run("Canvas Size...", "width="+x+" height="+y+" position=Center zero");
		run("32-bit");
		run("Stack to Hyperstack...", "order=xyczt(default) channels="+channels+" slices="+(slices*frames)+" frames=1 display=Color");
		//saveAs("Tiff", annotated_file);
		run("Make Windows", "window="+window_size+" z=1 staggered?");
		run("Make Composite", "display=Composite");
		run("Save As Tiff", "save=["+retrain_tmp_directory+"Img"+IJ.pad(number_of_files,2)+"]");
		run("Close All");
	}
}

//***************************COMBINE ANNOTATED FILE************************************
run("Image Sequence...", "open="+retrain_tmp_directory+" sort");
Stack.getDimensions(width, height, channels, slices, frames);
run("Stack to Hyperstack...", "order=xyczt(default) channels="+(no_channels+2)+" slices=1 frames="+(channels*slices*frames/(no_channels+2))+" display=Grayscale");
run("Save As Tiff", "save=["+retrain_file+"]");
rename(File.getName(retrain_file));

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

run("Concatenate...", "all_open");
rename(tt);

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
run("Save As Tiff", "save=["+rot_shift_retrain_file+"]");
run("Close All");
run("open URL", "url="+"http://"+machine+":8080/retrain?path="+source_dir);
run("open URL browser", "url=http://"+machine+":8008");