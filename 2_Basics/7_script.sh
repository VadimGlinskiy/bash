#!/bin/bash
#Функция, складывающая числа

sum=0

myFunction()
{
    echo "Это текст из функции"
    echo "Num1: $1"
    echo "Num2: $2"
    summa=$(($1+$2))
}

myFunction 50 10
echo "Sum=$summa"