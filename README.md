## DeepFiji

The repository contains python modules used by the Fiji macros to
run tensorflow training and inference from a general workstation
on our deep learning workstation, volta.

### Module descriptions

#### model_runner.py
```model_runner.py``` runs on deep learning workstation listening for requests on port 8080.
It handles running training and inference, and can also kill an existing process.
