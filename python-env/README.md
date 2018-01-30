## Python environment

Add anaconda3 binary to your path (in your `.bashrc` for instance)

```bash
export PATH="$PATH:/opt/anaconda3/bin"
```

To activate or deactivate the environment:

```bash
source activate pytorch-env
source deactivate
```

### Installation

Create anaconda environment and install packages. Be careful you are ROOT !

```bash
sudo su -
export PATH="$PATH:/opt/anaconda3/bin"
conda create --name pytorch-env
source activate pytorch-env
pip install -r requirement.txt
```

Install [SentEval](https://github.com/facebookresearch/SentEval) in `/opt/SentEval`

```bash
cd /opt
git clone https://github.com/facebookresearch/SentEval
cd SentEval/data
bash get_transfer_data_moses.bash
# bash get_transfer_data_ptb.bash
cd ..
python setup.py install
```

Building [PyTorch](https://github.com/pytorch/pytorch) from source does not work right now. You can install it with `conda install pytorch torchvision cuda80 -c soumith —name pytorch-env` and skip the following snippet.

```bash
cd /opt
export CMAKE_PREFIX_PATH="$(dirname $(which conda))/../"
conda install -c soumith magma-cuda80 --name pytorch-env
git clone --recursive https://github.com/pytorch/pytorch
cd pytorch
python setup.py install
```

Finish the work

```bash
source deactivate
exit
```

