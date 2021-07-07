# shell script to run complete FPGA flow
echo "================================================"
echo "WELCOME TO MAKERCHIP FPGA LAB"
echo "================================================" 

i=1

file="config.txt"
while read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    name[${i}]="${line}"
    i=$((i+1))
done < "$file"

cd ..

foldername=${name[0]}
echo "================================================"
echo "SELECT THE FOLDER : ${foldername} " 
echo "================================================"

cd ${foldername}

filename=${name[1]}
echo "================================================"
echo "WHICH FILE YOU WANT TO UPLOAD ON VIVADO : ${filename}"
echo "================================================"

board=${name[2]}
echo "================================================"
echo "WHICH BOARD YOU WANT TO USE (basys3, edge_artix-7, zedboard) : ${board}" 
echo "================================================"


echo "================================================"
echo "GOING TO THE REQUIRED DIRECTORY"
echo "================================================"

echo "================================================"
echo "DO YOU WANT TO DELETE PREVIOUS BUILD FILES" 
echo "------------------------------------------------" 
read -p "PRESS 'y' FOR YES OR 'n' FOR NO : " input
echo "================================================"

if [ $input == "y" ]
then
	echo "============================================" 	
	echo "REMOVING ALL THE PREVIOUS BUILD FILES"
	echo "--------------------------------------------"
	rm -rf out_${filename}_${board}
	echo "============================================"
else
	echo "============================================"
	read -p "CHANGE THE NAME OF THE PREVIOUS BUILD('out_${filename}') FOLDER , MAKE SURE ITS A NEW NAME: " folder_new_name
	echo "--------------------------------------------"
	mv out_${filename}_${board} $folder_new_name
	echo "--------------------------------------------"
	echo "CHANGED NAME OF 'out_${filename}' TO $folder_new_name"
	echo "============================================"
fi

# Give the respective tlv file as top. For eg, for counter test case give it as counter.tlv
echo "================================================"
echo "PROCESSING USING SANDPIPER(TM) SaaS EDITION."
echo "------------------------------------------------"
sandpiper-saas -i ${filename}.tlv -o ${filename}.v --iArgs --default_includes --outdir=out_${filename}_${board}
echo "================================================"

echo "================================================"
echo "DO YOU WANT TO USE YOUR CONSTRAINT FILE" 
read -p "PRESS 'y' FOR YES OR 'n' FOR NO : " mod 
if [ $mod == "y"]
then
	mv my_${filename}_fpga_lab_constr_${board}.xdc out_${filename}_${board}
echo "================================================"

echo "================================================"
cp ./../fpga_lab/contraints/${filename}_fpga_lab_constr_${board}.xdc ./${foldername}
echo "================================================="

echo "================================================="
echo "SETTING UP THE BOARD REQUIREMENTS"
echo "-------------------------------------------------"
read -p "INPUT THE CLOCK(in ns) AT WHICH YOU WANT TO RUN YOUR PROGRAM : " clock_rate
echo "================================================="

board_name=${name[3]}
echo "INPUT THE BOARD NAME WHICH YOU ARE USING : ${board_name}" 

echo $mod >> tmp.txt
echo $filename >> tmp.txt  
echo $clock_rate >> tmp.txt
echo $board_name >> tmp.txt
echo $board >> tmp.txt

path=$(pwd)
echo "================================================"

cd 
echo "================================================"
echo "SOURCING VIVADO"
echo "================================================"

cd vivado
source Vivado/2020.2/settings64.sh
cd 
cd ${path}
#cd out_${filename}_${board}
vivado -mode batch -source ./../fpga_lab/tcl_files/run_new.tcl 
rm -f tmp.txt

#we are in counter i.e. ${foldername} dir . 
