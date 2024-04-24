#!/bin/bash

mycomputer="Intel 2666v3"
myOS=$(uname -a)
echo "My PC: $mycomputer..."
echo "..."
echo "MyOS=$myOS"

echo "Название файла: $0"
echo "Создатель файла: $1..."
echo "$1 хочет стать $2"

num1=50
num2=45
summa=$((num1+num2))
echo "$num1 + $num2 = $summa"