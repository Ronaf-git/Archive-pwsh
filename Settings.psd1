
#This module is used to store variables between runs of the script
@{
# -------- Variables that you can change -------- 
    OutputGenericName = "MyArchive"  #Ex: MyArchive
    OutputFormat = ".zip"    #Ex: .zip
    OutputPath = 'D:\Users\'  #Ex: C:\Users\<MyUser>\Downloads\'
#/!\ The indexes of InputPaths and InputPathsTS must match /!\
#That means : if you add a InputPaths : You must add a value (0) in InputPathsTS, at the same index. If you delete a InputPaths : You must delete the value in InputPathsTS, at the same index
    InputPaths =  @('D:\Users\<MyUser>\Documents','D:\Users\<MyUser>\Videos') #Ex : C:\Users\<MyUser>\Videos
    InputPathsTS = @(0,0) #Ex : 0. It'll be changed after first run

# -------- Please don't touch theses -------- 
    LastRun = 29062024                    
}