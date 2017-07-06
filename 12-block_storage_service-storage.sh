#!/bin/bash

yum install lvm2 -y
systemctl enable lvm2-lvmetad.service
systemctl start lvm2-lvmetad.service
