import os
import sys
import time
import shutil
import cherrypy
import subprocess

class model_runner(object):

    gpustring = 'Tesla V100-PCIE-32GB'

    
    train_cmd = ['python',
                 '/n/projects/c2015/DeepFiji/Trainer.py']

    retrain_cmd = ['python',
                   '/n/projects/c2015/DeepFiji/Retrainer.py']
    
    infer_cmd = ['python',
                 '/n/projects/c2015/DeepFiji/Inferer.py']

    py_logdir = '/n/projects/c2015/DeepFiji/logs/'

    tb_logdir = '/scratch/c2015/DeepFiji/logs'
    tb_port = '8008'
    
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
            print(out)
            sout = out.split('\n')
            for line in sout:
                if self.gpustring in line:
                    res0 = line
                    break
            p = res0.split('|')
            print("************", p)
            res = int(p[-2].split('/')[0])
            if res > 0:
                res = 0
            else:
                res = 1
        except:
            print(sys.exc_info()[0])
            res = -1 #sys.exc_info()[0]

        return res


    @cherrypy.expose
    def checkgpu(self):
        a = self.is_gpu_available()
        if a == 1:
            return "GPU is available - 1"
        elif a == 0:
            return "GPU is busy - 0"
        else:
            return "maybe it is, maybe it isn't - check with nvidia-smi"


    def run_training(self, path, cmd):
        if model_runner.lock is True:
            return -2

        if self.is_gpu_available() < 1:
            print("***** check shows busy")
            return -1

        subprocess.run(['killall', 'tensorboard'])
        try:
            shutil.rmtree(self.tb_logdir)
        except:
            pass
        
        if os.path.exists("train.log"):
            os.remove("train.log")
            
        model_runner.f = open("train.log", 'w')
        #model_runner.lock = True

        cmd = cmd + [path]

        try:
            model_runner.f.close()
        except:
            pass
        
        model_runner.f = open(self.py_logdir + 'training.log', 'w')
        
        model_runner.proc = subprocess.Popen(cmd, stdout=model_runner.f,
                                             stderr=subprocess.STDOUT, bufsize=1,
                                             universal_newlines=True)

        res = "The model at " + path + " is training"
        if os.path.exists(path):
            res += "True "
        else:
            res += "False "
        #model_runner.lock = False
        return 0
    

    def run_tensorboard(self):
        cmd =['tensorboard',
              '--logdir=' + self.tb_logdir,
              '--port=' + self.tb_port,
              '--samples_per_plugin=images=0'
              ]

        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return "started tensorboard"
        

    def run_infer(self, path):
        if model_runner.lock is True:
            return -2
        #model_runner.lock = True

        if not self.is_gpu_available():
            return -1

        cmd = self.infer_cmd + [path]

        try:
            model_runner.f.close()
        except:
            pass
        
        model_runner.f = open(self.py_logdir + 'inferer.log', 'w')
        
        model_runner.proc = subprocess.Popen(cmd, stdout=model_runner.f,
                                             stderr=subprocess.STDOUT, bufsize=1,
                                             universal_newlines=True)
        
        res = "The model at " + path + " is inferring"
        if os.path.exists(path):
            res += "True "
        else:
            res += "False "
        #model_runner.lock = False
        return ' '.join(cmd)


    @cherrypy.expose
    def convert_path(self, path):
        print(path)
        repdict = { 'S:' : '/n/core',
                    'U:' : '/n/projects',
                    '/Volumes': '/n',
                    's:' : '/n/core',
                    'u:' : '/n/projects'
                    }
    
        path = path.replace('\\', '/')
        print(path)

        for key in repdict.keys():
            if key in path:
                v = repdict[key]
                path = path.replace(key, v)
                break

        res = path
        if not res.endswith('/'):
            res += '/'
        print(res)
        return res

    @cherrypy.expose
    def train(self, path='/n/core/micro'):
        path = self.convert_path(path)
        res = self.run_training(path, cmd=self.train_cmd)
        self.run_tensorboard()

        if res == 0:
            rs = "retraining check http://volta:" + self.tb_port + " to see progress"
        elif res == -1:
            rs = "gpu is busy"
        return  rs
        
        return rs


    @cherrypy.expose
    def infer(self, path='/n/core/micro'):
        path = self.convert_path(path)
        res = self.run_infer(path)
        return res

    @cherrypy.expose
    def retrain(self, path='/n/core/micro'):
        path = self.convert_path(path)
        res = self.run_training(path, cmd=self.retrain_cmd)
        self.run_tensorboard()
        if res == 0:
            rs = "retraining check http://volta:" + self.tb_port + " to see progress"
        elif res == -1:
            rs = "gpu is busy"
        return  rs
    
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

    @cherrypy.expose
    def kill(self):
        try:
            model_runner.proc.kill()
            model_runner.f.close()
            return("killed the process")
        except:
            return("couldn't kill - maybe  not running?")
    
if __name__ == '__main__':
    ## run this here please
    cherrypy.config.update({'server.socket_host': 'volta'})
    cherrypy.quickstart(model_runner())
