#!/bin/bash

x=$1

echo "Начало CASE..."
case $x in
        1) echo "Это число равняется 1";;
    [2-9]) echo "Число больше 1";;
  "Petya") echo "Hello $x";;
        *) echo "Аргумент не определен!"
esac
