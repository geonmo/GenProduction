#!/bin/bash

## Initialize envvars
source /opt/rh/devtoolset-4/enable 
source /opt/rh/python27/enable 

## Download packages
wget https://launchpad.net/mg5amcnlo/2.0/2.6.x/+download/MG5_aMC_v2.6.0.tar.gz
tar xzf MG5_aMC_v2.6.0.tar.gz
MG=MG5_aMC_v2_6_0
mv $MG ..
MG=`readlink -f ../$MG`

WORKDIR=`pwd`
cd $MG

## Install necessary components
bin/mg5_aMC <<EOF
install update
install zlib; install boost
install lhapdf6; install hepmc
install oneloop; install ninja;
install pythia8;
install collier
EOF

## (re)Compile OneLoop package with gfortran fix
\cp $WORKDIR/patch/avh_olo_print.f90 $MG/HEPTools/oneloop/OneLOop-3.6/src/
cd $MG/HEPTools/oneloop/OneLOop-3.6
./clean.sh
./create.py
\cp libavh_olo.a ../
cd -

## For the pythia8 - rebuild boost-iostream if absent
if [ ! -f $MG/HEPTools/lib/libboost_iostreams.so ]; then
  cd HEPTools/boost/boost_1_59_0
  ./bootstrap.sh --with-libraries=iostreams
  ./b2
  \cp stage/lib/* ../lib/
  cd ../../lib
  for i in ../boost/lib/libboost_iostreams*; do ln -s $i; done
  cd ../..
fi

## For the pythia8 - fix build flags
sed -i "s;PYTHIA8_PATH=NotInstalled;PYTHIA8_PATH=`pwd`/HEPTools/pythia8;g" $MG/Template/LO/Source/make_opts
sed -i 's;OUT+=" -ld";OUT+=" --libs";g' $MG/HEPTools/bin/pythia8-config
sed -i 's;OUT+=" -ld";OUT+=" --libs";g' $MG/HEPTools/pythia8/bin/pythia8-config

## Download lhapdf6 PDFSet(s)
## >> Please add other PDFSets if you think they are necessary
cd $MG/HEPTools/lhapdf6
bin/lhapdf get NNPDF23_lo_as_0130_qed

## For the HYU HTOP SGE cluster
\cp $WORKDIR/patch/cluster.py $MG/madgraph/various/
echo 'cluster_type = sge' >> $MG/input/mg5_configuration.txt
echo 'cluster_size = 96' >> $MG/input/mg5_configuration.txt

## Write setup script
echo > setup.shrc <<EOF
#!/bin/bash

source /opt/rh/devtoolset-4/enable 
source /opt/rh/python27/enable 

export PYTHONPATH=$MG/HEPTools/lhapdf6/lib64/python2.7/site-packages:$PYTHONPATH
export LD_LIBRARY_PATH=$MG/HEPTools/lhapdf6/lib:$LD_LIBRARY_PATH
EOF