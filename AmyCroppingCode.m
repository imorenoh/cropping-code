%Script written by Amy McKeown-Green on July 9, 2019 
%UC Berkeley, CA
%Purpose: Extract image files from Gatan Digital Micrograph in-situ folder
%tree system, crop them, and save the cropped images as a 16bit tif file 

    %%Input: this is a test #2
% 1) A text file (written by a Digital Micrograph script) that contains
%the dimensions of the ROI that will be cropped (ex: left right down up)

% 2) A folder containing Digital Micrograph in-situ data

    %%Limitations: 
% 1)Code was written for windows (mac users may need to change '/'
%to '\' and other small differences)

% 2)Code only works for videos that are under 1 Hour long (though it would
% be possible to edit it to work for videos > 1 Hour)

    %%Notes
% 1)Parallel pool must be started for parfor loop to work 

    %%Summary:
%i. Code asks for textfile with cropping ROI dimensions
%ii. Code asks for DM folder system 
%iii. Code asks for place tif files will be saved
%   NOTE: Title of dialog box should specify which imput the uigetdir or
%   uigetfile applies to 
%iv. Code finds frame rate and total number of frames in image 
%v. Code creates a core filename that will be used to find images
%vi. Code creates folder for saved data where user specified
%vii. Code copies first frame into saved folder to preserve metadata
%viii. Parfor loop can begin 
%   NOTE: Can change to regular for loop by deleting 'par' but slow!
%   a) The current min, sec, and frame are determined based on index
%   b) The number of digits of the min/sec/frame is determined and the
%   appropriate leading '0' in the naming is generated 
%   c) A file name is generated corresponding to the current min/sec/frame
%   d) dmread.m is used to open the dm4 file and creates column vector
%      NOTE: dmread.m can only be used to open files that have never been
%      editted in digital micrograph - if they have, use readDMFile.m
%   e) The column vector is re-shaped and the image cropped using the
%   imported ROI dimensions 
%ix. parfor loop ends and tiff files should be found in specified folder


clc 
clear variables %insures any previous indexing is removed prior to start
clear

%% SELECT THE DESIRED TEXT FILE WITH THE CROPPING DIMENSIONS 

%%User selects file

[filename, pathname] = uigetfile('*.*', '*SELECT TEXT FILE WITH CROPPING DIMENSIONS*', 'Select text file with cropping dimensions'); %Obtain desired file and pathname
fullpathname = strcat(pathname, filename); %Create full file pathname

%%Open file and scan
fileID = fopen(fullpathname, 'rt'); %Opening user selected file
Data = textscan(fileID, '%s', 'delimiter', '\n', 'whitespace', ' '); % Reading information inside a file

%%Isolate number data and convert from cell to double
TotHeadInfoStrcell = cellstr(Data{1,1}(1:1));
cellstrdimensions = (strsplit(TotHeadInfoStrcell{1,1},' ')); % Cuts string based on presence of " "
ROIdimensions = str2double(cellstrdimensions); % converst cell array to an array of doubles

%%Assign dimensions to variables (may seem redundant but reduces overhead for parfor loop)
left = ROIdimensions(1,1);
right=ROIdimensions(1,2);
down=ROIdimensions(1,3);
up=ROIdimensions(1,4);

%% Beginning of file accessing code 
%THIS PART OF THE CODE UNPACTS THE FOLDER/FILE TREE


mainfoldername = uigetdir('', '*SELECT FOLDER THAT CONTAINS DIGITAL MICROGRAPH IN-SITU DATA*'); %selects main folder that contains desired data

wheretosavename = uigetdir('','*SELECT LOCATION TO SAVE DATA*'); %selects where data will be saved 

%% Find Dimensions of Folder Tree: Hour, Minute, Second, Frame


%% 1) Find frame rate by determining the number of images in the first second

start = tic; %Times how long the data processing takes

firstsecond = char(strcat(mainfoldername,'\Hour_00\Minute_00\Second_00')); %name of the first second folder
numFilesInSecond00 =dir(firstsecond);
framerate = length(numFilesInSecond00)-2; %for some reason it is always off by 2 (hence -2)


%% 2) Find number of minute folders by finding number of folders inside of Hour_00

prepnumofmin = dir(char(strcat(mainfoldername,'\Hour_00'))); 
numofmin = length(prepnumofmin)-2; %for some reason it is always off by 2 (hence -2)

%% 3) Find number of frames in last second so that the index for the for loop 1:(unknown) can be determined 

%     i. deal with leading zeroes in the folder/file naming structure for
%     Minute

mindigit = numel(num2str(fix(abs(numofmin)))); %finds number of digits of the minute (1 or 2)
numof0sb4min=repmat('0', 1,(2-mindigit)); %makes a char of '0' that is 2-typeofminute long 
numofminstr= strcat(num2str(numof0sb4min), num2str(numofmin-1)); %makes 1 leading '0' for all integers <10 and no leading '0' for integers>10

%     ii. Find number of seconds in last minute by finding the number of folders
%inside of the last minute folder

prepnumofsecondsinlastmin = dir(char(strcat(mainfoldername,'\Hour_00\Minute_', numofminstr))); 
numofsecondsinlastmin = length(prepnumofsecondsinlastmin)-2; 

%     iii. Find number of seconds in the last minute (there might be fewer than the 60)

secdigit = numel(num2str(fix(abs(numofsecondsinlastmin)))); %finds number of digits of the minute (1 or 2)
numof0sb4sec=repmat('0', 1,(2-secdigit)); %makes a char of '0' that is 2-typeofminute long 
numofsecondsinlastminstr= strcat(num2str(numof0sb4sec), num2str(numofsecondsinlastmin-1)); %makes 1 leading '0' for all integers <10 and no leading '0' for integers>10

%     iv. Find number of frames in the last second

prepnumofframesinlastsec = dir(char(strcat(mainfoldername,'\Hour_00\Minute_', numofminstr,'\Second_', numofsecondsinlastminstr)));
numofframesinlastsec = length(prepnumofframesinlastsec)-2;

%     v. Find total number of frames 

TotalNumFrames = ((numofmin-1)*60*framerate)+((numofsecondsinlastmin-1)*framerate)+(numofframesinlastsec); 
%(because there is a different # of frames in the last second of the last minute, this rather complicated math is necessary) 

%% 4) Set up files names for opening the image files and saving them in a new location

%-----------------------------
specificfilename = prepnumofframesinlastsec(3,1).name; %gets name of one frame in the in-situ data
corefilenamecell = (strsplit(specificfilename,'_Hour')); %cuts it so there is just the core file name (no hour, minute, or second data)
corefilenamestr = corefilenamecell{1,1};
%-----------------------------
locationofmainfolder = strsplit(mainfoldername, corefilenamestr); %finds the pathname of the data folder 
locationofmainfolder =locationofmainfolder{1,1};
%-----------------------------
newfoldername=char(strcat(wheretosavename,'\', corefilenamestr, '_edit'));
mkdir(newfoldername); %Makes new folder where data will be saved 

    
%% Isolate metadata by copying the first image and moving it somewhere

firstframe = strcat(firstsecond, '\', corefilenamestr,'_Hour_00_Minute_00_Second_00_Frame_0000.dm4'); %initial pathname of file to be moved
copyfilename=strcat(newfoldername,'\',corefilenamestr, '_edit_Hour_00_Minute_00_Second_00_Frame_00000.dm4');  %final pathname of file to be moved
copyfile(firstframe, newfoldername); %copies filed --> preserving metadata
%% Set up the craziest for loop of all time!!!!!


parfor ii = 1:TotalNumFrames 

%% 1) define the current minute and second based off the frame number 

currentmin = floor((ii/(framerate*60))-(1/(2*framerate*60))); %floor rounds a number down to the lower integer (1.9-->1)
currentsec = floor((ii/framerate)-(1/(2*framerate))); % (ex. for frame1, floor(1/4)=0, so the current second is zero -- assumes framerate of 4)
%this is problematic as when frame#=4 and framerate =4 then floor(4/4)=1

%Since the file naming goes frame0000, frame0001, frame0002, frame0003,
%the fourth frame is actually still in second 0 (same applies to minute)so
%the solution is to subtract a small part from the ii/framerate term 

currentframe = rem((framerate+ii-1), framerate); %Since the naming of frames starts at 0000 not 0001 (the seemingly complicated framerate+ii-1 is necessary because the index ii starts at 1)
    
% The way second is defined it will keep growing past 60. This if/else
% statement deals with that and "resets
currentsec=currentsec-(floor(currentsec/60)*60);


%% 2) Address leading zero syntax issue for file naming of

%%Minutes
typeofminute = numel(num2str(fix(abs(currentmin)))); %finds number of digits of the minute (1 or 2)
numof0s=repmat('0', 1,(2-typeofminute)); %makes a char of '0' that is 2-typeofminute long 
currentminstr= strcat(num2str(numof0s), num2str(currentmin)); %%makes 1 leading '0' for all integers <10 and no leading '0' for integers>10

%%Seconds 
typeofsecond = numel(num2str(fix(abs(currentsec)))); %finds number of digits on the second (1 or 2)
numof0ssec=repmat('0', 1,(2-typeofsecond)); %makes a char of '0' that is 2-typeofsecond long
currentsecstr= strcat(num2str(numof0ssec), num2str(currentsec)); %%makes 1 leading '0' for all integers <10 and no leading '0' for integers>10
%%Frames
% addresses change in syntax for frame rate (frame rate can go up to 160)

typeofframe=numel(num2str(fix(abs(currentframe)))); %deals with leading zeros (0000) vs. (0001) vs. (0010) vs. (0100)
numof0sframe=repmat('0', 1,4-typeofframe);
frameratestr =strcat(num2str(numof0sframe), num2str(currentframe));%makes 3 leading '0' for all integers <10 and 2 leading '0' for 10<int<100 and 1 leading '0' for int>100
        
    
%% 3) Create filename that changes with each loop

currentfoldername = strcat(mainfoldername, '\Hour_00\Minute_', currentminstr,'\Second_',currentsecstr) ; %The current folder based on the minute and second values determined by the index


%% 4) Get file name determined by index and read dm4 file

imagefilepathname = strcat(currentfoldername, '\',corefilenamestr,'_Hour_00_Minute_', currentminstr, '_Second_', currentsecstr, '_Frame_', frameratestr, '.dm4'); %name of image file based on index
       % imageb = ReadDMFile(imagefilepathname); %this DM4 reader only
       % works on in-situ data that has been editted --> no clue why
              %for editted data --> uncomment below and comment the next 5 lines of code 
              %imagearray = ReadDMFile(imagefilepathname); 
              
Imagestruc = dmread(imagefilepathname); %reads dm4 file
imagedata =Imagestruc.ImageList.Unnamed0.ImageData.Data.Value; %extracts column vector from struc array
Dimensionx =Imagestruc.ImageList.Unnamed0.ImageData.Dimensions.Unnamed0.Value; %extracts x-dimension of image 
Dimensiony =Imagestruc.ImageList.Unnamed0.ImageData.Dimensions.Unnamed1.Value; %extracts y-dimension of image
imagearray=reshape(imagedata, [Dimensionx, Dimensiony]); %re-shapes column vector into a matrix defined by its x and y-dimension

imaged1=transpose(imagearray);%for some reason the image is flipped when it goes through the dm4 reader and this fixes that
        
%% 5) Crop the image 

imagecropped = imaged1(left:right,down:up); % crops image 
imagegrysc=uint16(65536*mat2gray(imagecropped)); %normalizes --> max pixel value = 1 and min =0 --> converts to integer necessary for tiff
imagefiletiff= strcat(wheretosavename,'\', corefilenamestr, '_edit','\', corefilenamestr,'_edit_', num2str(ii),'.tif'); %writes new file name
imwrite(imagegrysc, imagefiletiff); %writes a tiff file       
   
end
