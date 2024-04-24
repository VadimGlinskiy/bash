#!/bin/bash
myhost=$(hostname)
mygtw="8.8.8.8"

ping -c 4 $myhost
ping -c 4 $mygtw

echo -n "Готово! "
echo "На той же строчке"