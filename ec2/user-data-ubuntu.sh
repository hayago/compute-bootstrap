#!/bin/bash
set -eux

git clone https://github.com/hayago/compute-bootstrap.git
bash compute-bootstrap/ec2/boostrap-ubuntu.sh

