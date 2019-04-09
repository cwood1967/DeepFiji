import os
import sys
import cherrypy
import subprocess

class model_runner(object):
    
    gpustring = 'Tesla V100-PCIE-32GB'
    train_cmd = ['python',
                 '/scratch/cjw/DeepLearning/Trainer.py']

    infer_cmd = ['python',
                 '/scratch/cjw/DeepLearning/Inferer.py']

    lock = False
    proc = None

    f = None
    
    def __init__(self):
        pass
        #self.lock = False
        
    def is_gpu_available(self):
        try:
            proc = subprocess.run(['gpustat'],
                                  stdout=subprocess.PIPE,
                                  encoding='utf-8')
            out = proc.stdout
            sout = out.split('\n')
            for line in sout:
                if self.gpustring in line:
                    res0 = line
                    break
            p = res0.split('|')
            res = int(p[-2].split('/')[0])
            if res > 0:
                res = False
            else:
                res = True
        except:
            res = sys.exc_info()[0]

        return res


    @cherrypy.expose
    def checkgpu(self):
        a = self.is_gpu_available()
        if a:
            return "GPU is available"
        else:
            return "GPU is busy"


    def run_training(self, path):
        if model_runner.lock is True:
            return "Already running ....?"

        if not self.is_gpu_available():
            return "GPU is busy"
        
        if os.path.exists("train.log"):
            os.remove("train.log")
            
        model_runner.f = open("train.log", 'w')
        model_runner.lock = True
        print(path, "\nLD ", os.environ['LD_LIBRARY_PATH'])
        cmd = self.train_cmd + [path]
        model_runner.proc = subprocess.Popen(cmd, stdout=model_runner.f,
                                           bufsize=1)
        res = "The model at " + path + " is training"
        if os.path.exists(path):
            res += "True "
        else:
            res += "False "
        #model_runner.lock = False
        return ' '.join(cmd)
    

    def run_tensorboard(self):
        cmd =['tensorboard',
              '--logdir=/scratch/cjw/DeepLearning/logs',
              '--port=8009',
              "--samples_per_plugin=images=0"
              ]

        subprocess.Popen(cmd)
        return "started tensorboard"
        

    def run_infer(self, path):
        if model_runner.lock is True:
            return "Already running....?"
        model_runner.lock = True
        cmd = self.infer_cmd + [path]
        model_runner.proc = subprocess.run(cmd, stdout=subprocess.PIPE,
                                           universal_newlines=True,
                                           bufsize=1)
        
        res = "The model at " + path + " is inferring"
        if os.path.exists(path):
            res += "True "
        else:
            res += "False "
        model_runner.lock = False
        return ' '.join(cmd)


    @cherrypy.expose
    def train(self, path='/n/core/micro'):
        res = self.run_training(path)
        self.run_tensorboard()
        
        return "check http://volta:8009 to see progress"


    @cherrypy.expose
    def infer(self, path='/n/core/micro'):
        res = self.run_infer(path)
        return res

    @cherrypy.expose
    def retrain(self, path='/n/core/micro'):
        # retrainer.py
        pass
    
    @cherrypy.expose
    def is_locked(self):
        return str(model_runner.lock)


    @cherrypy.expose
    def set_lock(self):
        model_runner.lock = True
        return "locked"


    @cherrypy.expose
    def get_stdout(self):
        return model_runner.f.read()
    
if __name__ == '__main__':
    ## run this here please
    cherrypy.config.update({'server.socket_host': 'volta'})
    cherrypy.quickstart(model_runner())
