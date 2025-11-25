#!/usr/bin/env bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games:/home/pi/.dotnet
BEGINTIME=$(date)
#Remove previous files
rm /home/pi/workspace/logo*jpg
rm /home/pi/workspace/resized*
rm /home/pi/workspace/text*
rm /home/pi/workspace/GOES*jpg
#rm /home/pi/workspace/GOEStemp.gif

echo "Process starting at " $BEGINTIME 

# Set filepath and outputfilename from parameters
FILEPATH=$1
OUTPUTPATH=$2
FRAMERATE=$3
MAXFOLDERS=$4

#Testing
FILEPATH='fd/fc'
OUTPUTPATH='fd_fc'
FRAMERATE=20
MAXFOLDERS=5 #set to zero if the files are already copied
TAGFILES='true' #Run the process to add annotations and logo
US_ONLY='false' #Runs the Sanchez process to create a US map

#If maxfolders > 0 then delete all of the files in the folder.  If = 0 then we want those files
if false; then
#if [ "$MAXFOLDERS" > 0 ]; then
	echo "Removing previous workspace files"
	rm /home/pi/workspace/*
fi

CUSER=$USER
echo 'Running as ' $CUSER
echo 'Filepath is ' $FILEPATH
echo 'OutputPath is' $OUTPUTPATH
#Loop through all of the date-named folders
LOOPCOUNT=1
#MAXFOLDERS=10 #maximum number of daily folders to load (actual number loaded is determined by finding zero filelength
while [[ "$LOOPCOUNT" -le "$MAXFOLDERS" ]]; do
        #Get date of earliest folder in fd/fc folder
        #FILEDATE=$(ssh pi@192.168.50.146 ls -l /home/pi/goes16/$FILEPATH | cut -c 38-48 | sort | tail -$LOOPCOUNT | head -1 | xargs)
	#FILEDATE=$(ssh pi@192.168.50.146 ls -l /media/pi/TRANSCEND1TB/goes/$FILEPATH | cut -c 38-48 | sort | tail -$LOOPCOUNT | head -1 | xargs)
	#FILEDATE=$(ssh pi@192.168.50.146 ls -l /media/pi/M2/goes19/$FILEPATH | cut -c 38-48 | sort | tail -$LOOPCOUNT | head -1 | xargs)
	FILEDATE=$(ssh pi@192.168.50.146 ls -l /media/pi/M21/goes19/$FILEPATH | cut -c 40-53 | sort | tail -$LOOPCOUNT | head -1 | xargs)

	#FILEDATE=$(ls -l /mnt/goes16/$FILEPATH | cut -c 38-48 | sort | tail -$LOOPCOUNT | head -1 | xargs)
	#FILEDATE=$(ssh pi@192.168.50.146 ls -l /home/pi/goes16/$FILEPATH | cut -c 38-48 | sort | tail -$LOOPCO>

	FILELENGTH=$(expr length "$FILEDATE")
    echo 'File date is ' $FILEDATE ' Length is ' $FILELENGTH

	#List of dates has blank record at end.  Dont download if the file already exists
	if [ $FILELENGTH -gt 3 ]; then

	    #Copy the contents of that folder to the local workspace
		#echo 'Filepath is /home/pi/goes16/'$FILEPATH'/'$FILEDATE'/*'
		#FULLFILEPATH='/mnt/goes16/'$FILEPATH'/'$FILEDATE'/*'
		#FULLFILEPATH='ssh pi@192.168.50.44 ls -l /media/pi/TRANSCEND1TB/goes/'$FILEPATH'/'$FILEDATE'/*'

		echo 'Copying full filepath ' $FILEPATH $FILEDATE
	    scp pi@192.168.50.146:/media/pi/M21/goes19/$FILEPATH/$FILEDATE/* /home/pi/workspace/
		#scp pi@192.168.50.146:$FULLFILEPATH /home/pi/workspace/
		#cp $FULLFILEPATH /home/pi/workspace/

	    LOOPCOUNT=$[$LOOPCOUNT+1]
	else
		break
	fi
done

---------------------------------------------------------------------------------------------------------------------
# If this is M1 or M2 FC channel delete the files for overnight. Don't need to do it for the enhanced channels
cd /home/pi/workspace
#find | grep FD_FC | grep T0 | xargs rm -f
find | grep M1_FC | grep T0 | xargs rm -f
find | grep M2_FC | grep T0 | xargs rm -f
find | grep M1_CH02_ | grep T0 | xargs rm -f
find | grep M2_CH02_ | grep T0 | xargs rm -f

# Remove files that cause flare
rm GOES*0530*
#---------------------------------------------------------------------------------------------------------------
#Use Sanchez to clean coloring on FD_FC files
echo 'Filepath is '$FILEPATH
#if  false; then
#if [[ $FILEPATH = 'fd/fc' ]] || [[ $FILEPATH = 'fd/ch13' ]]; then 
	echo "Starting enhanced processing for FD_FC"
	cd /home/pi/workspace
	#Clear work folders
	rm /home/pi/workspace/fd_enhance/*
	rm /home/pi/workspace/fd_enhance_out/*
	#Copy source files to the work folder for Sanchez
	echo "Copying files to enhanced folder for preprocessing"
	cp /home/pi/workspace/GOES*jpg /home/pi/workspace/fd_enhance/
	#delete zero-length files
	echo "Deleting zero-length files"
	find /home/pi/workspace/fd_enhance -size 0 -print -delete
	#Process the files
	echo "Starting Sanchez process"
	#/home/pi/Programs/Sanchez/sanchez-v1.0.24-linux-arm/Sanchez -s "/home/pi/workspace/fd_enhance/GOES*" -v -u "/home/pi/sanchez-v1.0.18-linux-x64/Resources/world.200411.3x10848x5424.jpg" -o  "/home/pi/workspace/fd_enhance_out"

if [[ $US_ONLY != 'true' ]]; then
		#Sanchez will run for full picture
	/home/pi/sanchez/output/Sanchez -s "/home/pi/workspace/fd_enhance/GOES*" -v -u "/home/pi/sanchez/output/Resources/world.200411.3x10848x5424.jpg" -o  "/home/pi/workspace/fd_enhance_out"
else
	#Sanchez will run and produce a picture of only the US
	/home/pi/sanchez/output/Sanchez reproject --lon -144:-44 --lat 9:54 -s "/home/pi/workspace/fd_enhance/GOES*" -v -u "/home/pi/sanchez/output/Resources/world.200411.3x10848x5424.jpg" -o  "/home/pi/workspace/fd_enhance_out"
fi
	
#Remove the unprocessed files from workspace
rm /home/pi/workspace/GOES*jpg
#copy the processed files into the workspace for subsequent processing
echo "Copying processed files back into workspace"
cp /home/pi/workspace/fd_enhance_out/*  /home/pi/workspace

#---------------------------------------------------------------------------------------------------------------
#Add filename textbox to file
cd /home/pi/workspace
echo "Removing text* files if present"
#rm text*
echo "Removing zero-length files"
find /home/pi/workspace/ -size 0 -print -delete
echo "Adding filenames to images"
if [[ $TAGFILES = 'true' ]]; then
	for FILENAME in GOES*.jpg
		do
			if [[ ${FILENAME:0:12} = 'GOES19_fd_fc' ]]; then #Good
				echo 'Adding text to ' $FILENAME
				composite -watermark 50% -gravity northeast /home/pi/skunkworks20neg.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 70  -gravity center  -annotate +0+1000 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:14} = 'GOES19_fd_ch15' ]]; then #Good
				echo 'Adding text to ' $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks20neg.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 100  -gravity center  -annotate +0+2000 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:14} = 'GOES19_fd_ch02' ]]; then #Good
				echo 'Adding text to ' $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks20neg.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 100  -gravity center  -annotate +0+2000 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:14} = 'GOES19_fd_ch09' ]]; then #Good
				echo 'Adding text to ' $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks20neg.jpg $FILENAME logo_$FILENAME             
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 100  -gravity center  -annotate +0+2000 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:14} = 'GOES19_fd_ch13' ]]; then #Good
				echo 'Adding text to ' $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks15neg.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 50  -gravity center  -annotate +0+800 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:14} = 'GOES19_m_ch02' ]]; then
				echo 'Adding text to ' $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks15neg.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 30  -gravity center  -annotate +0+200 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:14} = 'GOES19_m1_ch07' ]]; then
				echo 'Adding text to ' $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks2.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 8  -gravity center  -annotate +0+200 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:14} = 'GOES19_m1_ch08' ]]; then
				echo "Converting " $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks15neg.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 8  -gravity center  -annotate +0+200 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:14} = 'GOES19_m1_ch09' ]]; then
				echo "Converting " $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks1.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 8  -gravity center  -annotate +0+200 $FILENAME text_$FILENAME
			fi


			if [[ ${FILENAME:0:14} = 'GOES19_m1_ch13' ]]; then #Revise
				echo "Converting " $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks2.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 8  -gravity center  -annotate +0+200 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:12} = 'GOES19_m1_ch' ]]; then #Revise
				echo "Converting " $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks10neg.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 50  -gravity center  -annotate +0+400 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:12} = 'GOES19_m2_fc' ]]; then
				echo "Converting " $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks10neg.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 50  -gravity center  -annotate +0+400 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:14} = 'GOES19_m2_ch02' ]]; then
				echo "Converting " $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks15neg.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill white -pointsize 50  -gravity center  -annotate +0+2000 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:13} = 'GOES19_ft_sst' ]]; then #Revise
				echo "Converting " $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks20.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill black -pointsize 100  -gravity center  -annotate +0+2000 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:13} = 'GOES19_fd_tpw' ]]; then #Revised
				echo "Converting " $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks5.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill black -pointsize 30  -gravity center  -annotate +0+400 $FILENAME text_$FILENAME
			fi

			if [[ ${FILENAME:0:15} = 'GOES19_fd_rrpqe' ]]; then #Revised
				echo "Converting " $FILENAME
				composite -watermark 40% -gravity northeast /home/pi/skunkworks20.jpg $FILENAME logo_$FILENAME
				convert logo_$FILENAME  -font helvetica -fill black -pointsize 100  -gravity center  -annotate +0+2000 $FILENAME text_$FILENAME
			fi
		done
fi
#---------------------------------------------------------------------------------------------------------------
#Copy the most recent file of each type  to the current files folder
#Note - the T18 will get the files at time 1800 which may not be the most recent file. It's only the most recent from the day in which we have T1800 data
LASTFILE=$(ls  -l text_GOES*.jpg | grep T18 | tail -1 | sed 's/^.*GOES/GOES/' )
echo  "Most recent file: " $LASTFILE
cp text_$LASTFILE "/home/pi/current_jpg/current_"$OUTPUTPATH.jpg

#----------------------------------------------------------------------------------------------------------------
# Run convert to change the file resolution so ffmpeg doesn't barf
STARTTIME=$(date)
echo "Starting resizing "  $STARTTIME
#For 2048 images - gets "Cache resources exhausted" error on Pi
#convert 'text*.jpg[2048x]' resized_1000%03d.jpg

#try this on the Pi - works
#convert 'text*.jpg[1024x]' resized_1000%03d.jpg

#now convert to 640x480
convert 'text*.jpg[640x]' resized_1000%03d.jpg
#----------------------------------------------------------------------------------------------------------
#Run FFmpeg to create the videos
#FRAMERATE=6
echo "Framerate = " $FRAMERATE
echo "Starting convert " $(date)

#start smooth conversion
convert -loop 0 -delay $FRAMERATE "resized*.jpg" "GOEStemp.gif"

echo "Starting FFmpeg " $(date)
cp GOEStemp.gif $OUTPUTPATH.gif
rm  $OUTPUTPATH"_"$FRAMERATE.mp4

if [[ $US_ONLY != 'true' ]]; then
	ffmpeg -y -i GOEStemp.gif -filter "minterpolate='mi_mode=blend'" -c:v libx264 -pix_fmt yuv420p "/home/pi/workspace/"$OUTPUTPATH"_"$FRAMERATE.mp4
else 
	ffmpeg -y -i GOEStemp.gif -filter "minterpolate='mi_mode=blend'" -c:v libx264 -pix_fmt yuv420p "/home/pi/workspace/US_"$OUTPUTPATH"_"$FRAMERATE.mp4
fi

#Original conversion below
#cat resized*.jpg | ffmpeg -y -framerate $FRAMERATE -f image2pipe -i - $OUTPUTPATH"_"$FRAMERATE.avi
#cat resized*.jpg | ffmpeg -y -framerate $FRAMERATE -f image2pipe -i - $OUTPUTPATH"_"$FRAMERATE.mp4

#  this is the conversion to smooth transitions ffmpeg -i input.mkv -filter:v "minterpolate='mi_mode=mci:mc_mode=aobmc:vsbmc=1:fps=60'" output.mkv

#This does the conversion for YouTube
#ffmpeg -y -i $OUTPUTPATH"_"$FRAMERATE.avi  -c:v libx264 -preset slow -crf 18 -c:a copy -pix_fmt yuv420p $OUTPUTPATH"_"$FRAMERATE"_"youtube.mkv

ENDTIME=$(date)
echo "Created " $OUTPUTPATH"_"$FRAMERATE mp4
echo "Process started at " $BEGINTIME " with " $MAXFOLDERS " days of data"
echo "Starting convert "  $STARTTIME
echo "Ending at " $ENDTIME
echo ""
echo ""
exit
