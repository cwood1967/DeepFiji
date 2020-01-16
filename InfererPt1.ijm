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

process_dir=source_dir+"Data"+File.separator;
model_dir=source_dir+"NewModels"+File.separator;
inference_dir=source_dir+"Data_input"+File.separator;
output_dir=source_dir+"Data_output"+File.separator;
final_dir=source_dir+"Final"+File.separator;

File.makeDirectory(inference_dir);
File.makeDirectory(output_dir);
File.makeDirectory(final_dir);

IJ.log(process_dir);

config_file=source_dir+"Network.txt";
f=File.openAsString(config_file);
lines=split(f, "\n");
base_scaler=parseInt(lines[0]);
baseline_noise=parseFloat(lines[1]);
x_dim=parseInt(lines[2]);
mean=parseFloat(lines[3]);
std=parseFloat(lines[4]);
model_no=parseInt(lines[5]);
no_channels=parseInt(lines[6]);

Dialog.create("Model selection");
Dialog.addNumber("Model override?", -1);
Dialog.show();
tmp_model=parseInt(Dialog.getNumber());
if (tmp_model!=-1)
{
	model_no=tmp_model;
}

f=File.open(config_file);
print(f, ""+base_scaler+"\n"+baseline_noise+"\n"+x_dim+"\n"+mean+"\n"+std+"\n"+model_no+"\n"+no_channels+"\n");
File.close(f);

Dialog.create("Choose machine");
Dialog.addChoice("Machine", newArray("tesla", "volta"));
Dialog.show();
machine=Dialog.getChoice();

function break_and_save()
{
	limit=12*1024*1024*1024;
	Stack.getDimensions(width, height, channels, slices, frames);
	frame_size=width*height*4*channels;
	total_size=width*height*4*channels*frames;
	num_images=floor(total_size/limit)+1;
	if (floor(total_size/limit)==total_size/limit) num_images=num_images-1;

	frames_per_batch=floor(frames/num_images)+1;
	if (floor(frames/num_images)==frames/num_images) frames_per_batch=frames_per_batch-1;
	curt=getTitle();

	IJ.log(""+frame_size);
	IJ.log(""+total_size);
	IJ.log(""+num_images);
	IJ.log(""+frames_per_batch);
	
	for (i=0; i<num_images; i++)
	{
		selectWindow(curt);
		fstart=1+i*frames_per_batch;
		fstop=fstart+frames_per_batch-1;
		fstop=minOf(frames, fstop);
		IJ.log(""+fstart+","+fstop);
		run("Duplicate...", "duplicate frames="+fstart+"-"+fstop);
		run("Save As Tiff", "save=["+inference_dir+infile_name+"pt"+i+"]");
		close();
	}	
}

process_list = getFileList(process_dir);
IJ.log(process_list[0]);
for (n=0; n<process_list.length; n++)
{
	cur_file=process_dir+process_list[n];
	IJ.log(cur_file);
	open(cur_file);
	Stack.getDimensions(width, height, channels, slices, frames);

	x=(floor((width-1)/x_dim)+1)*x_dim;
	y=(floor((height-1)/x_dim)+1)*x_dim;

	run("Canvas Size...", "width="+x+" height="+y+" position=Center zero");
	run("32-bit");	
	if (channels*slices*frames>1) run("Stack to Hyperstack...", "order=xyczt(default) channels="+channels+" slices="+(slices*frames)+" frames=1 display=Color");
	
	run("Make Windows", "window="+x_dim+" z=1 staggered?");
	//run("Make Composite", "display=Grayscale");
	infile_name=process_list[n];
	//run("Save As Tiff", "save=["+inference_dir+infile_name+"]");
	break_and_save();
	run("Close All");

}

////*****************CALL WEBPAGE*********************************
run("open URL", "url="+"http://"+machine+":8080/infer?path="+source_dir);