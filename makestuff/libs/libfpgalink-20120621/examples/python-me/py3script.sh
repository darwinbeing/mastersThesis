dd of=/var/tmp/foo.dat if=/dev/urandom bs=65536 count=160
sudo LD_LIBRARY_PATH=../../linux.x86_64/rel ./fpgalink3.py -s -v 1443:0007 -i 1443:0007 -x ../../hdl/fx2/vhdl/ex_cksum-me/top_level.xsvf -f /var/tmp/foo.dat
