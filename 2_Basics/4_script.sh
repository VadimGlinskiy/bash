#!/bin/bash

if [ "$1" == "Vasya" ]; then
    echo "Привет, $1"
elif [ "$1" == "Trump" ]; then
    echo "Hello $1"
else
    echo "Greeting $1"
fi

x=$2

echo "Начало CASE..."
case $x in
        1) echo "Это число равняется 1";;
    [2-9]) echo "Число больше 1";;
  "Petya") echo "Hello $x";;
        *) echo "Аргумент не определен!"
esac
