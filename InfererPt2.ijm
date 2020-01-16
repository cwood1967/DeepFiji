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
x_dim=parseInt(lines[2]);
model_no=IJ.log(lines[5]);

output_list = getFileList(output_dir);
for (n=0; n<output_list.length; n++)
{
	cur_file=process_dir+output_list[n];
	if (endsWith(cur_file, "pt0.tif"))
	{
		cur_file=substring(cur_file, 0, lengthOf(cur_file)-7);
		IJ.log(cur_file);
		open(cur_file);
		Stack.getDimensions(width, height, channels, slices, frames);
		x=(floor((width-1)/x_dim)+1)*x_dim;
		y=(floor((height-1)/x_dim)+1)*x_dim;
		close();
	
		
		current_index=0;
		cur_file=output_dir+output_list[n];
		cur_file=substring(cur_file, 0, lengthOf(cur_file)-7);
		nxt_file=cur_file+"pt"+current_index+".tif";
		IJ.log(nxt_file);
		while (File.exists(nxt_file))
		{
			//cur_file=output_dir+output_list[n];
			IJ.log(nxt_file);
			open(nxt_file);
			//run("Bio-Formats Importer", "open="+cur_file+" color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
			current_index=current_index+1;
			nxt_file=cur_file+"pt"+current_index+".tif";
		}
		if (current_index>1) run("Concatenate...", "all_open open");
		Stack.getDimensions(widthb, heightb, channelsb, slicesb, framesb);
		run("Stack to Hyperstack...", "order=xyczt(default) channels="+channelsb+" slices="+(1)+" frames="+(slicesb*framesb)+" display=Composite");
	
		border=30;
		makeRectangle(border, border, x_dim-2*border, x_dim-2*border);
		run("Clear Outside", "stack");
		run("Make Image From Windows", "width="+x+" height="+y+" slices="+(slices*frames)+" staggered?");
		run("Make Composite", "display=Composite");
		Stack.setChannel(channelsb-1);
		setMinAndMax(0, 1.0);
		Stack.setChannel(channelsb);
		setMinAndMax(0, 1.0);
	
		Stack.getDimensions(widthb, heightb, channelsb, slicesb, framesb);
		makeRectangle(floor((widthb-width)/2), floor((heightb-height)/2), width,height);
		run("Crop");
	
		infile_name=output_list[n];
		//saveAs("Tiff", final_dir+infile_name);
		run("Save As Tiff", "save=["+final_dir+substring(infile_name,0,lengthOf(infile_name)-7)+"]");
		run("Close All");
	}

}
