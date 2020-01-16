Dialog.create("Choose machine");
Dialog.addChoice("Machine", newArray("tesla", "volta"));
Dialog.show();
machine=Dialog.getChoice();

run("open URL", "url="+"http://"+machine+":8080/kill");