C:
cd\
md webcacheTemp
robocopy "C:\webcacheTemp" "C:\Users\Default\AppData\Local\Microsoft\Windows\WebCache" /mir
rd webcacheTemp
pause