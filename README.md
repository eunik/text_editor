# Text Editor - CSC 210
This project uses assembly languange, mainly tasm, a 32-bit x86 MS-DOS.  
This project is a text editor that allows saving, quitting, file clearing, and encrypting.

## Prerequisites
You will need to install [DosBox](https://www.dosbox.com/download.php?main=1) and set it up correctly. [Link](https://www.dosbox.com/wiki/Basic_Setup_and_Installation_of_DosBox)

## Running the Program
You must run it like below or you will get an error message.
```
tasm myed.asm
tlink myed/t
myed try.txt
```

## Instructions
```
*run in DOS with "C>myed try.txt"
*Type anything to write to file.
*press 'backspace' to delete (since it's based on
insert, it only erase at the position and won't move.
*CTRL + Q: quit
*CTRL + S: save
*CTRL + E: encrypt
*CTRL + N: clears the file and quits

*If you go or type till the end of the column,
it will go to a new line at col = 0.
*If you press left arrow at col = 0 it will go up
1 line and at the last column.

Happy editting.
```
