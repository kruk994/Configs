Compiled list of my shell tricks

Things you can put in your ~/.zshrc:
PROMPT='%n@%m %~ %# '
Will make prompt look a little nicer + will show your current directory
Like marvin@c1r1s1 ~/42_Piscine % 
(I saw a people using pwd almost everytime they do cd )

2. mkcd() {
	mkdir -p -- "$1" && cd -P -- "$1"
}
Creates a mkcd command which creates a directory and instantly navigates it
Combined mkdir and cd

3. subject() {
	wget -NP ~/.cache -nv -- "$1" && pdftotext -nopgbrk -layout -- ~/.cache/"${1##*/}" - | uniq | less
}
Creates a subject command that downloads PDF file and display it in terminal + allows you to navigate in it using less
It first checks if existing file in ~/.cache is the same at link to avoid redownloading same file each time
For example, subject https://cdn.intra.42.fr/pdf/pdf/96987/en.norm.pdf will download (if it doesn't exist) and open the en.norm.pdf file

4. alias ll="ls -lA"
The command ll that displays detailed list and includes hidden files

5. alias cc="cc -Wall -Wextra -Werror"
The command cc will compile with all needed flags

6. You can also check out Oh My Zsh for more customization options

Don't to forget to reload shell by typing source ~/.zshrc after adding stuff in it



Tricks with shell:
You can chain commands using && 
For example cc ft_task.c && ./a.out 'Test' will compile AND test script immediately afterwards if one succeed first

2. Ctrl + R allows you to search for used commands in current session
Eliminates need to you to repeatedly press UP arrow

3. You can pipe xclip -selection clipboard to copy the text from file
For example, cat ~/.zshrc | xclip -selection clipboard will copy entire content of ~/.zshrc to your system clipboard

4. Use less instead of cat to view large files
It's way nicer to view files this way + allows you to flexibly navigate + doesn't clutter your terminal

5. Ctrl + L clears your terminal
Basically clear, but faster with shortcut

6. echo "*.out\n*.swp" >> .gitignore will create .gitignore file with added exceptions (compiled C files and Vim session files) in it
Eliminates need to use vim for adding simple few lines text

7. You can use mkdir ex{00..08} to create multiple "ex" directories (from ex00 to ex08) at once

8. Ctrl + U will clear current entered prompt
Useful if you need to remove longest command without waiting for Backspace to finish its job

9. tree is a very handy command when it comes checking the structure of your files in project
tree -a will include hidden files

10. git remote set-url (name) (new url) will change current repository link to new one
Useful if you need to redo evaluations on a new given git@vogsphere.42warsaw.pl repository

11. apropos can search man pages for commands, headers and libraries for you

12. Try curl cht.sh :3
